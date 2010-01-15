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

Rem
	bbdoc: This type represents a container in Cloud Files
	about:
End Rem
Type TRackspaceCloudFilesContainer
	Field _name:String
	Field _rackspace:TRackspaceCloudFiles
	Field _url:String
	
'	Rem
'		bbdoc: 
'		about:
'	End Rem
	Method Create:TRackspaceCloudFilesContainer(rackspace:TRackspaceCloudFiles, name:String)
		Self._name = name
		Self._rackspace = rackspace
		Self._url = rackspace._storageUrl + "/" + name
		Return Self
	End Method

	Rem
		bbdoc: Returns the name of the container
		about:
	End Rem
	Method Name:String()
		Return Self._name
	End Method
	
	Rem
		bbdoc: Returns the total number of objects in the container
		about:
	End Rem
	Method ObjectCount:Int()
		Local response:TRESTResponse = Self._rackspace._Transport(Self._url, Null, "HEAD")
		Select response.responseCode
			Case 204
				Return response.GetHeader("X-Container-Object-Count").ToInt()
			Default
				Throw New TRackspaceCloudFilesContainerException.SetMessage("Unable to handle response")
		End Select
		Return 0
	End Method
	
	Rem
		bbdoc: Returns the total number of bytes used by objects in the container
		about:
	End Rem
	Method BytesUsed:Long()
		Local response:TRESTResponse = Self._rackspace._Transport(Self._url, Null, "HEAD")
		Select response.responseCode
			Case 204
				Return response.GetHeader("X-Container-Bytes-Used").ToInt()
			Default
				Throw New TRackspaceCloudFilesContainerException.SetMessage("Unable to handle response")
		End Select
		Return 0
	End Method
	
	Rem
		bbdoc: Returns a list of objects in the container. As the API only returns ten thousand objects per request, this module may have to do multiple requests to fetch all the objects in the container. You can also pass in a prefix
		about: Set prefix to retrieve only the objects beginning with that name
	End Rem
	Method Objects:TList(prefix:String = Null, limit:Int = 10000, marker:String = Null)
		Local qs:String = TURLFunc.CreateQueryString(["limit=" + limit, "prefix=" + TURLFunc.EncodeString(prefix, False, True), "marker=" + TURLFunc.EncodeString(marker, False, True)])
		Local response:TRESTResponse = Self._rackspace._Transport(Self._url + qs, Null, "GET")
		Select response.responseCode
			Case 200
				Local objectsList:TList = New TList
				If response.content.Length = 0
					Return objectsList
				End If
				
				Local objects:String[] = response.content.Trim().Split("~n")
				For Local objectName:String = EachIn objects
					If objectName.Length = 0 Then Continue
					objectsList.AddLast(Self.FileObject(objectName))
				Next
				
				'Check if there are more objects
				If objectsList.Count() = limit
					Local lastObject:TRackspaceCloudFileObject = TRackspaceCloudFileObject(objectsList.Last())
					Local more:TList = Self.Objects(prefix, limit, lastObject._name)
					'If the list has items then add them to the mainlist
					If more.Count() > 0
						For Local c:TRackspaceCloudFileObject = EachIn more
							objectsList.AddLast(c)
						Next
					End If
				End If
				
				Return objectsList
			Case 204
				Return New TList
			Default
				Throw New TRackspaceCloudFilesContainerException.SetMessage("Unable to handle response")
		End Select
	End Method
	
	Rem
		bbdoc: This returns an object
		about:
	End Rem
	Method FileObject:TRackspaceCloudFileObject(name:String)
		Return New TRackspaceCloudFileObject.Create(Self, name)
	End Method
	
	Rem
		bbdoc: Deletes the container, which should be empty
		about:
	End Rem
	Method Remove()
		Local response:TRESTResponse = Self._rackspace._Transport(Self._url, Null, "DELETE")
		Select response.responseCode
			Case 204
				'OK
			Case 409
				Throw New TRackspaceCloudFilesContainerException.SetMessage("Container not empty!")
			Default
				Throw New TRackspaceCloudFilesContainerException.SetMessage("Unable to handle response")
		End Select
	End Method
End Type
