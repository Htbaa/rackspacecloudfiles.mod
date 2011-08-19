Rem
	Copyright (c) 2010 Christiaan Kras
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
End Rem

SuperStrict

Rem
	bbdoc: htbaapub.rackspacecloudfiles
EndRem
Module htbaapub.rackspacecloudfiles
ModuleInfo "Name: htbaapub.rackspacecloudfiles"
ModuleInfo "Version: 1.09"
ModuleInfo "License: MIT"
ModuleInfo "Author: Christiaan Kras"
ModuleInfo "Git repository: <a href='http://github.com/Htbaa/rackspacecloudfiles.mod/'>http://github.com/Htbaa/rackspacecloudfiles.mod/</a>"
ModuleInfo "Rackspace Cloud Files: <a href='http://www.rackspacecloud.com'>http://www.rackspacecloud.com</a>"
ModuleInfo "History: 1.09"
ModuleInfo "History: Added check to prevent expiration of authToken. This allows applications to run for over 24-hours with the same TRackspaceCloudFiles object."
ModuleInfo "History: TRackspaceCloudFiles.Create now accepts a third parameter 'location'. This allows authentication to either the USA or UK server."

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
	Field _location:String
	
	Field _progressCallback:Int(data:Object, dltotal:Double, dlnow:Double, ultotal:Double, ulnow:Double)
	Field _progressData:Object
	
	Rem
		bbdoc: URL for data stored in the USA
	End Rem	
	Const LOCATION_USA:String = "https://auth.api.rackspacecloud.com/v1.0"
	
	Rem
		bbdoc: Url for data stored in the UK
	End Rem
	Const LOCATION_UK:String = "https://lon.auth.api.rackspacecloud.com/v1.0"

	Rem
		bbdoc: Optionally set the path to a certification bundle to validate the SSL certificate of Rackspace
		about: If you want to validate the SSL certificate of the Rackspace server you can set the path to your certificate bundle here.
		This needs to be set BEFORE creating a TRackspaceCloudFiles object, as TRackspaceCloudFiles.Create() automatically calls Authenticate()
	End Rem
	Global CAInfo:String
	
	Rem
		bbdoc: Creates a TRackspaceCloudFiles object
		about: This method calls Authenticate()
		location can be either the LOCATION_USA or LOCATION_UK constant
	End Rem
	Method Create:TRackspaceCloudFiles(user:String, key:String, location:String = LOCATION_USA)
		Self._authUser = user
		Self._authKey = key
		Self._location = location
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
		
		Local response:TRESTResponse = Self._Transport(Self._location, headers)
		
		If response.IsSuccess()
			Self._storageToken = response.GetHeader("X-Storage-Token")
			Self._storageUrl = response.GetHeader("X-Storage-Url")
			Self._cdnManagementUrl = response.GetHeader("X-CDN-Management-Url")
			Self._authToken = response.GetHeader("X-Auth-Token")
		ElseIf response.IsClientError()
			Throw New TRackspaceCloudFilesException.SetMessage("Invalid account or access key!")
		Else
			Throw New TRackspaceCloudFilesException.SetMessage("Unable to handle response!")
		End If
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
		If response.IsSuccess()
			Return Self.Container(name)
		End If
		Throw New TRackspaceCloudFilesException.SetMessage("Unable to handle response!")
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
		If response.IsSuccess()
			Return response.GetHeader("X-Account-Bytes-Used").ToLong()
		End If
		Throw New TRackspaceCloudFilesException.SetMessage("Unable to handle response!")
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
		
		'Prevent expiration of authToken
		If response.responseCode = 401 And Self._authToken
			Self.Authenticate()
			Return Self._Transport(url, headers, requestMethod, userData)
		End If
		
		Return response
	End Method

End Type