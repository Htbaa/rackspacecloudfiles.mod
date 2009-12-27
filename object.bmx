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
	
	Field _metaData:TMap
	
'	Rem
'		bbdoc:
'		about:
'	End Rem
	Method Create:TRackspaceCloudFileObject(container:TRackspaceCloudFilesContainer, name:String)
		Self._name = name
		Self._rackspace = container._rackspace
		Self._container = container
		
		Self._url = container._rackspace._storageUrl + "/" + container.Name() + "/"
		Local parts:String[] = ExtractDir(Self._name).Split("/")
		For Local part:String = EachIn parts
			If part.Length = 0 Then Continue
			Self._url:+TURLFunc.EncodeString(part, False, False) + "/"
		Next
		
		Self._url:+TURLFunc.EncodeString(StripDir(Self._name), False, False)

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
		Local response:TRESTResponse = Self._rackspace._Transport(Self._url, Null, "HEAD")
		Select response.responseCode
			Case 404
				Throw New TRackspaceCloudFileObjectException.SetMessage("Object " + Self._name + " not found")
			Case 204
				Self._SetAttributesFromResponse(response)
			Default
				Throw New TRackspaceCloudFileObjectException.SetMessage("Unable to handle response")
		End Select
	End Method

	Rem
		bbdoc: Fetches the metadata and content of an object
		about: Returns data content
	End Rem
	Method Get:String()
		Local response:TRESTResponse = Self._rackspace._Transport(Self._url, Null)
		Select response.responseCode
			Case 404
				Throw New TRackspaceCloudFileObjectException.SetMessage("Object " + Self._name + " not found")
			Case 200
				Self._SetAttributesFromResponse(response)
				If Self._etag <> MD5(response.content).ToLower()
					Throw New TRackspaceCloudFileObjectException.SetMessage("Data corruption error")
				End If
				Return response.content
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
		Local response:TRESTResponse = Self._rackspace._Transport(Self._url, Null, "DELETE")
		Select response.responseCode
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
		Local md5Hex:String = MD5(stream)
		stream.Seek(0)
		
		Local headerList:TList = New TList
		headerList.AddLast("ETag: " + md5Hex.ToLower())
		headerList.AddLast("Content-Type: " + TRackspaceCloudFileObject.ContentTypeOf(filename))

		Self._PrepareMetaDataForTransfer(headerList)
		
		Local headerArray:String[] = New String[headerList.Count()]
		For Local i:Int = 0 To headerArray.Length - 1
			headerArray[i] = String(headerList.ValueAtIndex(i))
		Next
		
		Local response:TRESTResponse = Self._rackspace._Transport(Self._url, headerArray, "PUT", stream)
		Select response.responseCode
			Case 201
				'Object created
				Self._SetAttributesFromResponse(response)
			Case 412
				Throw New TRackspaceCloudFileObjectException.SetMessage("Missing Content-Length or Content-Type header")
			Case 422
				Throw New TRackspaceCloudFileObjectException.SetMessage("Data corruption error")
			Default
				Throw New TRackspaceCloudFileObjectException.SetMessage("Unable to handle response")
		End Select
	End Method

'	Rem
'		bbdoc: Private method
'	End Rem
	Method _PrepareMetaDataForTransfer(headerList:TList)
		If Self._metaData
			For Local key:String = EachIn Self._metaData.Keys()
				Local content:String = TURLFunc.EncodeString(String(Self._metaData.ValueForKey(key)))
				headerList.AddLast("X-Object-Meta-" + key + ": " + content)
			Next
		End If
	End Method
	
	Rem
		bbdoc: Clear meta data
		about: To remove all meta data call this method before saving
	End Rem
	Method ClearMetaData()
		If Self._metaData Then Self._metaData.Clear()
	End Method
	
	Rem
		bbdoc: Set meta data for an object
		about: Remember that the key and value together shouldn't exceed 4096 bytes
	End Rem
	Method SetMetaData(key:String, value:String)
		If Not Self._metaData Then Self._metaData = New TMap
		If key.Length + value.Length > 4096
			Throw New TRackspaceCloudFileObjectException.SetMessage("Length of metadata's key and value should not exceed 4096 bytes")
		End If
		Self._metaData.Insert(key, value)
	End Method
	
	Rem
		bbdoc: Save changes to meta data
		about: Save changes to meta data done with @SetMetaData() without having to re-upload the file contents
	End Rem
	Method SaveMetaData()
		Local headerList:TList = New TList
		Self._PrepareMetaDataForTransfer(headerList)
		
		Local headerArray:String[] = New String[headerList.Count()]
		For Local i:Int = 0 To headerArray.Length - 1
			headerArray[i] = String(headerList.ValueAtIndex(i))
		Next

		Local response:TRESTResponse = Self._rackspace._Transport(Self._url, headerArray, "POST")
		Select response.responseCode
			Case 202
				'ok
			Case 404
				Throw New TRackspaceCloudFileObjectException.SetMessage("Object doesn't exist")
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
	
	Rem
		bbdoc: Return meta data
		about: Returns the meta data. Don't directly edit this data structure! Use @SetMetaData() instead!
	End Rem
	Method MetaData:TMap()
		Return Self._metaData
	End Method
	
'	Rem
'		bbdoc: Private method
'	End Rem
	Method _SetAttributesFromResponse(response:TRESTResponse)
		Self._etag = response.GetHeader("Etag")
		Self._size = response.GetHeader("Content-Length").ToLong()
		Self._contentType = response.GetHeader("Content-Type")
		Self._lastModified = response.GetHeader("Last-Modified")
		
		Self.ClearMetaData()
		For Local key:String = EachIn response.headers.Keys()
			If key.Contains("X-Object-Meta-")
				Local strippedKey:String = key[14..].Trim()
				Local content:String = TURLFunc.DecodeString(String(response.GetHeader(key)))
				Self.SetMetaData(strippedKey, content)
			End If
		Next
	End Method
End Type
