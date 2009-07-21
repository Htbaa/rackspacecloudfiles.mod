SuperStrict
Import htbaapub.rackspacecloudfiles

'Make sure a file called credentials.txt is available
'On the first line the username is expected. On the second line the API key is expected.
Local credentials:String[] = LoadText("credentials.txt").Split("~n")
If Not credentials.Length = 2
	RuntimeError("Invalid configuration file!")
End If

'Create our TRackspaceCloudFiles object
Local mcf:TRackspaceCloudFiles = New TRackspaceCloudFiles.Create(credentials[0].Trim(), credentials[1].Trim())

Print "Total bytes used: " + mcf.TotalBytesUsed()

'list all containers
Local containers:TList = mcf.Containers()
For Local container:TRackspaceCloudFilesContainer = EachIn containers
	Print "Container: " + container.Name() + " --- Object count: " + container.ObjectCount()
Next

'create a new container. If the container already exists it'll be returned as well
Local container:TRackspaceCloudFilesContainer = mcf.CreateContainer("testing")

'use an existing container
Local existingContainer:TRackspaceCloudFilesContainer = mcf.Container("testing2")

Print "Object count: " + container.ObjectCount()
Print container.BytesUsed() + " bytes"

Local objects:TList = container.Objects()
For Local obj:TRackspaceCloudFileObject = EachIn objects
	Print "have object " + obj.Name()
Next

'You can also request a objects list that is prefixed
'Local objects2:TList = container.Objects("dir/")

'To create a new object with the contents of a local file
Local obj1:TRackspaceCloudFileObject = container.FileObject("Test1.txt")
obj1.PutFile("credentials.default.txt")

Print obj1.ETag()
Print obj1.LastModified()

'To download an Object To a Local file
obj1.GetFile("test.DOWNLOADED")

'Delete the object from the container
obj1.Remove()

'Remove the container
container.Remove()
