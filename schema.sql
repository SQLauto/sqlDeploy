CREATE TABLE [dbo].deployment_history
(
	Id INT NOT NULL PRIMARY KEY IDENTITY,
	FileName varchar(1000) NOT NULL,
	StartedTime datetime2 NOT NULL, 
	FinishedTime datetime2, 
	Status varchar(100) NOT NULL,
	Output varchar(max)
)

GO

CREATE INDEX [IX_Deployment_History_FileName] ON [dbo].[deployment_history] ([FileName])
