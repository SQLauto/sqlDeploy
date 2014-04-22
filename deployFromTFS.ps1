param (
	[string] $path = ".",
	[string] $server = "(localdb)\v11.0",
	[string] $database = "Test",
	[switch] $strict,
	[string] $tfsUrl = "http://tfs.niaid.nih.gov:8080/tfs",
	[string] $tfsPath = "$/CustomDevelopment/NEAR/Database/Deltas/NEAR 2.5.0",
	[string] $pathToTFexe = "C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\TF.exe"
)
#usage: .\deployFromTFS.ps1 -path .\SQL -server ai-dbdev1 -database Test -strict

$fullpath = rvpa $path
echo "Source directory: $fullpath"
echo "Target server: $server"
echo "Target database: $database"

#-----------------------  TFS --------------------------
echo ""
echo "Connecting to TFS server $tfsUrl"

cd $path
& "$pathToTFexe" workspace /new _SQLDeploy /server:"$tfsUrl" /location:local /noprompt
& "$pathToTFexe" workfold "$tfsPath" . /workspace:"_SQLDeploy"
& "$pathToTFexe" get /noprompt 
& "$pathToTFexe" workspace /delete _SQLDeploy /noprompt

#------------------  SIGNATURES ------------------------
if($strict) {
	echo ""
	echo "Verifying signatures..."
	$files = @(ls $path -i *.sql -r)
	foreach ($file in $files) {
		echo ""
		if(test-path ($file.FullName + ".asc")) {
			echo "Verifying ASCII signature found for $($file.Name)"
			gpg --verify ($file.FullName + ".asc")
			if($lastexitcode -ne 0) {
				$oops = $true
			}
		}
		elseif(test-path ($file.FullName + ".sig")) {
			echo "Verifying binary signature found for $($file.Name)"
			gpg --verify ($file.FullName + ".sig")
			if($lastexitcode -ne 0) {
				$oops = $true
			}
		}
		else {
			echo "No signature found for $($file.Name)"
			$oops = $true
		}
	}
	if($oops){
		echo ""
		echo "One or more files either lack signature or have been tampered with."
		echo "Aborting deployment."
		break
	}
	else {
		echo ""
		echo "All signatures look good."
	}
}


#------------------  SQL ------------------------
echo ""
echo "Running SQL..."

$sql = New-Object System.Data.SqlClient.SqlConnection
$sql.ConnectionString = "Server=$server;Database=$database;Integrated Security=True"
$cmd = $sql.CreateCommand()
$sql.Open()
try {
	$prefix = "
		SET XACT_ABORT ON
		BEGIN TRAN
		GO
	"

	$postfix = "
		GO
		COMMIT TRAN
	"

	#----------------  GETTING LIST OF FILES ----------------
	$files = @(ls $path -i *.sql -r)
	$count = $files.Length
	echo "$count .sql file(s) found."
	
	$i = 1
	$ran = 0
	$skipped = 0
	$cantRun = 0
	# ----------  PROCESSING EACH FILE ----------------
	foreach ($file in $files) {
		echo ""	
		echo "file #$($i): $($file.Name)"
		
		#-------------  SEE IF WE HAVE TO SKIP THIS ONE -----------------
		$cmd.CommandText = "SELECT COUNT(*) FROM deployment_history WHERE fileName='$file' AND status='success'"
		$ranBefore = $cmd.ExecuteScalar()
		
		if($ranBefore -gt 0){
			echo "ran before, skipping"
			$skipped++
		}
		elseif($sqlError){
			echo "can't run because of an error in one of the files above"
			$cantRun++
		}
		#-----------------------  RUNNING INDIVIDUAL FILE -----------------------
		else {
			echo "running..."
			
			$cmd.CommandText = "INSERT INTO deployment_history (fileName, startedTime, status) VALUES ('$file', getdate(), 'running'); SELECT @@IDENTITY"
			$id = $cmd.ExecuteScalar()

			$output = ((@($prefix) + (cat $file) + @($postfix)) | sqlcmd -S "$server" -d $database -b -X)
			#-------------------- FAILURE -----------------------
			if($lastexitcode -ne 0) {
				echo "SQLCMD returned an error:"
				echo $output
				echo "Aborting the sequence on $($file.Name)"

				$outputSql = $output.Replace("'", "''")
				$cmd.CommandText = "UPDATE deployment_history SET finishedTime=getdate(), status='failure', output='$outputSql' WHERE id=$id"
				$rowcount = $cmd.ExecuteNonQuery()
				
				$sqlError = $true
			}
			#-------------------- SUCCESS -----------------------
			else {
				echo $output
				echo "done!"
    			$outputSql = $output.Replace("'", "''")
				$cmd.CommandText = "UPDATE deployment_history SET finishedTime=getdate(), status='success', output='$outputSql' WHERE id=$id"
				$rowcount = $cmd.ExecuteNonQuery()
				$ran++
			}
		}
		$i++
	}
	
	echo ""
	echo "Out of $count files,"
	if($ran -gt 0) { echo "$ran ran successfully" }
	if($skipped -gt 0) { echo "$skipped were skipped because they ran before" }
	if($sqlError) { echo "1 failed" }
	if($cantRun -gt 0) { echo "$cantRun did not run at all" }
}
finally {
	$sql.Close()
}
