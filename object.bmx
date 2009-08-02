Rem
	bbdoc: This type represents an object in Cloud Files
	info:
End Rem
Type TRackspaceCloudFileObject
	Field _name:String
	Field _contentType:String
	Field _etag:String
	Field _size:Long
	Field _lastModified:String
	
	Field _rackspace:TRackspaceCloudFiles
	Field _container:TRackspaceCloudFilesContainer
	Field _url:String
	
'	Rem
'		bbdoc:
'		about:
'	End Rem
	Method Create:TRackspaceCloudFileObject(container:TRackspaceCloudFilesContainer, name:String)
		Self._name = name
		Self._rackspace = container._rackspace
		Self._container = container
		
		Local urlDirname:String = ExtractDir(Self._name)
		Local urlFilename:String = EncodeString(StripDir(Self._name), False, False)
		If urlDirname.Length > 0 Then urlDirname:+"/"
		
		Self._url = container._rackspace._storageUrl + "/" + container.Name() + "/" + urlDirname + urlFilename
		Return Self
	End Method

	Rem
		bbdoc: Returns the name of the object
		about:
	End Rem
	Method Name:String()
		Return Self._name
	End Method

	Rem
		bbdoc: Fetches the metadata of the object
		about:
	End Rem
	Method Head()
		Select Self._rackspace._Transport(Self._url, Null, "HEAD")
			Case 404
				Throw New TRackspaceCloudFileObjectException.SetMessage("Object " + Self._name + " not found")
			Case 204
				Self._SetAttributesFromResponse()
			Default
				Throw New TRackspaceCloudFileObjectException.SetMessage("Unable to handle response")
		End Select
	End Method

	Rem
		bbdoc: Fetches the metadata and content of an object
		about: Returns data content
	End Rem
	Method Get:String()
		Select Self._rackspace._Transport(Self._url, Null)
			Case 404
				Throw New TRackspaceCloudFileObjectException.SetMessage("Object " + Self._name + " not found")
			Case 200
				Self._SetAttributesFromResponse()
				If Self._etag <> MD5(Self._rackspace._content).ToLower()
					Throw New TRackspaceCloudFileObjectException.SetMessage("Data corruption error")
				End If
				Return Self._rackspace._content
			Default
				Throw New TRackspaceCloudFileObjectException.SetMessage("Unable to handle response")
		End Select
	End Method

	Rem
		bbdoc: Downloads the content of an object to a local file, checks the integrity of the file, sets metadata in the object <strike>and sets the last modified time of the file to the same as the object</strike>
		about:
	End Rem
	Method GetFile:String(filename:String)
		SaveText(Self.Get(), filename)
		Return filename
	End Method

	Rem
		bbdoc: Deletes an object
		about:
	End Rem
	Method Remove()
		Select Self._rackspace._Transport(Self._url, Null, "DELETE")
			Case 404
				Throw New TRackspaceCloudFileObjectException.SetMessage("Object " + Self._name + " not found")
			Case 204
				'OK
			Default
				Throw New TRackspaceCloudFileObjectException.SetMessage("Unable to handle response")
		End Select
	End Method

	Rem
		bbdoc: Creates a new object with the contents of a local file
		about: Remember that the max. filesize supported by Cloud Files is 5Gb
	End Rem
	Method PutFile(filename:String)
		Local stream:TStream = ReadStream(filename)
		Local md5Hex:String = MD5(LoadText(filename))
		Local headers:String[] = ["ETag: " + md5Hex.ToLower(), "Content-Type: " + TRackspaceCloudFileObject.ContentTypeOf(filename) ]

		Select Self._rackspace._Transport(Self._url, headers, "PUT", stream)
			Case 201
				'Object created
				Self._SetAttributesFromResponse()
			Case 412
				Throw New TRackspaceCloudFileObjectException.SetMessage("Missing Content-Length or Content-Type header")
			Case 422
				Throw New TRackspaceCloudFileObjectException.SetMessage("Data corruption error")
			Default
				Throw New TRackspaceCloudFileObjectException.SetMessage("Unable to handle response")
		End Select
	End Method

	Rem
		bbdoc: Return content-type of a file
		about: Decision is based on the file extension. Which is not a safe method and the list
		of content types and extensions is far from complete. If no matching content type is being
		found it'll return application/octet-stream.<br>
		<br>
		The list content-type > file extension mapping can be found in <a href="../content-types.txt">content-types.txt</a>.
		This file is IncBinned during compilation of the module.
	End Rem
	Function ContentTypeOf:String(filename:String)
		Global mapping:TMap = New TMap
		
		If mapping.IsEmpty()
			Local strMapping:String[] = LoadText("incbin::content-types.txt").Split("~n")
			
			For Local line:String = EachIn strMapping
				Local parts:String[] = line.Split(":")
				Local contentType:String = parts[0]
				Local exts:String[] = parts[1].Split(",")
				For Local ext:String = EachIn exts
					mapping.Insert(ext, contentType.ToLower())
				Next
			Next
		End If
		
		Local contentType:String = String(mapping.ValueForKey(ExtractExt(filename).ToLower()))
		If Not contentType
			contentType = "application/octet-stream"
		End If
		Return contentType
	End Function
	
	Rem
		bbdoc: Returns the entity tag of the object, which is its MD5
		about:
	End Rem
	Method ETag:String()
		Return Self._etag
	End Method

	Rem
		bbdoc: Return the size of an object in bytes
		about:
	End Rem
	Method Size:Long()
		Return Self._size
	End Method

	Rem
		bbdoc: Return the content type of an object
		about:
	End Rem
	Method ContentType:String()
		Return Self._contentType
	End Method

	Rem
		bbdoc: Return the last modified time of an object
		about:
	End Rem
	Method LastModified:String()
		Return Self._lastModified
	End Method
	
'	Rem
'		bbdoc: Private method
'	End Rem
	Method _SetAttributesFromResponse()
		Self._etag = String(Self._rackspace._headers.ValueForKey("Etag"))
		Self._size = String(Self._rackspace._headers.ValueForKey("Content-Length")).ToLong()
		Self._contentType = String(Self._rackspace._headers.ValueForKey("Content-Type"))
		Self._lastModified = String(Self._rackspace._headers.ValueForKey("Last-Modified"))
	End Method
End Type
