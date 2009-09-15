SuperStrict

Rem
	bbdoc: htbaapub.rackspacecloudfiles
EndRem
Module htbaapub.rackspacecloudfiles
ModuleInfo "Name: htbaapub.rackspacecloudfiles"
ModuleInfo "Version: 1.05"
ModuleInfo "Author: Christiaan Kras"
ModuleInfo "Git repository: <a href='http://github.com/Htbaa/rackspacecloudfiles.mod/'>http://github.com/Htbaa/rackspacecloudfiles.mod/</a>"
ModuleInfo "Rackspace Cloud Files: <a href='http://www.rackspacecloud.com'>http://www.rackspacecloud.com</a>"

Import bah.crypto
Import htbaapub.rest
Import brl.linkedlist
Import brl.map
Import brl.retro
Import brl.standardio
Import brl.stream
Import brl.system

Include "exceptions.bmx"
Include "container.bmx"
Include "object.bmx"

Incbin "content-types.txt"

Rem
	bbdoc: Interface to Rackspace CloudFiles service
	about: Please note that TRackspaceCloudFiles is not thread safe (yet)
End Rem
Type TRackspaceCloudFiles
	Field _authUser:String
	Field _authKey:String
	
	Field _storageToken:String
	Field _storageUrl:String
	Field _cdnManagementUrl:String
	Field _authToken:String
'	Field _authTokenExpires:Int
	
	Field _progressCallback:Int(data:Object, dltotal:Double, dlnow:Double, ultotal:Double, ulnow:Double)
	Field _progressData:Object

	Rem
		bbdoc: Optionally set the path to a certification bundle to validate the SSL certificate of Rackspace
		about: If you want to validate the SSL certificate of the Rackspace server you can set the path to your certificate bundle here.
		This needs to be set BEFORE creating a TRackspaceCloudFiles object, as TRackspaceCloudFiles.Create() automatically calls Authenticate()
	End Rem
	Global CAInfo:String
	
	Rem
		bbdoc: Creates a TRackspaceCloudFiles object
		about: This method calls Authenticate()
	End Rem
	Method Create:TRackspaceCloudFiles(user:String, key:String)
		Self._authUser = user
		Self._authKey = key
		Self.Authenticate()
		Return Self
	End Method

	Rem
		bbdoc: Authenticate with the webservice
	End Rem
	Method Authenticate()
		Local headers:String[2]
		headers[0] = "X-Auth-User: " + Self._authUser
		headers[1] = "X-Auth-Key: " + Self._authKey
		
		Local response:TRESTResponse = Self._Transport("https://api.mosso.com/auth", headers)
		
		Select response.responseCode
			Case 204
				Self._storageToken = response.GetHeader("X-Storage-Token")
				Self._storageUrl = response.GetHeader("X-Storage-Url")
				Self._cdnManagementUrl = response.GetHeader("X-CDN-Management-Url")
				Self._authToken = response.GetHeader("X-Auth-Token")
			Case 401
				Throw New TRackspaceCloudFilesException.SetMessage("Invalid account or access key!")
			Default
				Throw New TRackspaceCloudFilesException.SetMessage("Unable to handle response!")
		End Select
	End Method
	
	Rem
		bbdoc: List all the containers
		about: Set prefix if you want to filter out the containers not beginning with the prefix
	End Rem
	Method Containers:TList(prefix:String = Null, limit:Int = 10000, marker:String = Null)
		Local qs:String = TURLFunc.CreateQueryString(["limit=" + limit, "prefix=" + TURLFunc.EncodeString(prefix, False, True), "marker=" + TURLFunc.EncodeString(marker, False, True)])
		Local response:TRESTResponse = Self._Transport(Self._storageUrl + qs)
		Select response.responseCode
			Case 200
				Local containerList:TList = New TList
				Local containerNames:String[] = response.content.Split("~n")
				For Local containerName:String = EachIn containerNames
					If containerName.Length = 0 Then Continue
					containerList.AddLast(New TRackspaceCloudFilesContainer.Create(Self, containerName))
				Next
				
				'Check if there are more containers
				If containerList.Count() = limit
					Local lastContainer:TRackspaceCloudFilesContainer = TRackspaceCloudFilesContainer(containerList.Last())
					Local more:TList = Self.Containers(prefix, limit, lastContainer._name)
					'If the list has items then add them to the mainlist
					If more.Count() > 0
						For Local c:TRackspaceCloudFilesContainer = EachIn more
							containerList.AddLast(c)
						Next
					End If
				End If
				
				Return containerList
			Case 204
				Return New TList
			Default
				Throw New TRackspaceCloudFilesException.SetMessage("Unable to handle response!")
		End Select
		Return Null
	End Method
	
	Rem
		bbdoc: Create a new container
		about:
	End Rem
	Method CreateContainer:TRackspaceCloudFilesContainer(name:String)
		Local response:TRESTResponse = Self._Transport(Self._storageUrl + "/" + name, Null, "PUT")
		Select response.responseCode
			Case 201 'Created
				Return Self.Container(name)
			Case 202 'Already exists
				Return Self.Container(name)
			Default
				Throw New TRackspaceCloudFilesException.SetMessage("Unable to handle response!")
		End Select
	End Method
	
	Rem
		bbdoc: Use an existing container
		about:
	End Rem
	Method Container:TRackspaceCloudFilesContainer(name:String)
		Return New TRackspaceCloudFilesContainer.Create(Self, name)
	End Method
	
	Rem
		bbdoc: Returns the total amount of bytes used in your Cloud Files account
		about:
	End Rem
	Method TotalBytesUsed:Long()
		Local response:TRESTResponse = Self._Transport(Self._storageUrl, Null, "HEAD")
		Select response.responseCode
			Case 204
				Return response.GetHeader("X-Account-Bytes-Used").ToLong()
			Default
				Throw New TRackspaceCloudFilesException.SetMessage("Unable to handle response!")
		End Select
		Return 0
	End Method
	
	Rem
		bbdoc: Set a progress callback function to use when uploading or downloading data
		about: This is passed to cURL with setProgressCallback(). See bah.libcurlssl for more information
	End Rem
	Method SetProgressCallback(progressFunction:Int(data:Object, dltotal:Double, dlnow:Double, ultotal:Double, ulnow:Double), progressObject:Object = Null)
		Self._progressCallback = progressFunction
		Self._progressData = progressObject
	End Method
	
'	Rem
'		bbdoc: Private method
'		about: Used to send requests. Sets header data and content data. Returns HTTP status code
'	End Rem
	Method _Transport:TRESTResponse(url:String, headers:String[] = Null, requestMethod:String = "GET", userData:Object = Null)
		Local headerList:TList = New TList
		If headers <> Null
			For Local str:String = EachIn headers
				headerList.AddLast(str)
			Next
		End If
		
		'Pass auth-token if available
		If Self._authToken
			headerList.AddLast("X-Auth-Token:" + Self._authToken)
		End If
		
		Local headerArray:String[] = New String[headerList.Count()]
		For Local i:Int = 0 To headerArray.Length - 1
			headerArray[i] = String(headerList.ValueAtIndex(i))
		Next

		Local request:TRESTRequest = New TRESTRequest
		request.SetProgressCallback(Self._progressCallback, Self._progressData)
		Local response:TRESTResponse = request.Call(url, headerArray, requestMethod, userData)
		Return response
	End Method

End Type