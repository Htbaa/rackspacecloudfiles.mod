SuperStrict

Rem
	bbdoc: htbaapub.rackspacecloudfiles
EndRem
Module htbaapub.rackspacecloudfiles
ModuleInfo "Name: htbaapub.rackspacecloudfiles"
ModuleInfo "Version: 1.01"
ModuleInfo "Author: Christiaan Kras"
ModuleInfo "Special thanks to: Kris Kelly"
ModuleInfo "Git repository: <a href='http://github.com/Htbaa/htbaapub.mod/'>http://github.com/Htbaa/htbaapub.mod/</a>"
ModuleInfo "Rackspace Cloud Files: <a href='http://www.rackspacecloud.com'>http://www.rackspacecloud.com</a>"

Import bah.crypto
Import bah.libcurlssl
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
	
	Field _headers:TMap
	Field _content:String

	Rem
		bbdoc: Optionally set the path to a certification bundle to validate the SSL certificate of Rackspace
		about: If you want to validate the SSL certificate of the Rackspace server you can set the path to your certificate bundle here.
		This needs to be set BEFORE creating a TRackspaceCloudFiles object, as TRackspaceCloudFiles.Create() automatically calls Authenticate()
	End Rem
	Global CAInfo:String
	
	Method New()
		?Threaded
		DebugLog "Warning: TRackspaceCloudFiles is not thread-safe. It's not safe to do multiple requests at the same time on the same object."
		?
	End Method
	
	Rem
		bbdoc: Creates a TRackspaceCloudFiles object
		about: This method calls Authenticate()
	End Rem
	Method Create:TRackspaceCloudFiles(user:String, key:String)
		Self._headers = New TMap
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
		Select Self._Transport("https://api.mosso.com/auth", headers)
			Case 204
				Self._storageToken = String(Self._headers.ValueForKey("X-Storage-Token"))
				Self._storageUrl = String(Self._headers.ValueForKey("X-Storage-Url"))
				Self._cdnManagementUrl = String(Self._headers.ValueForKey("X-CDN-Management-Url"))
				Self._authToken = String(Self._headers.ValueForKey("X-Auth-Token"))
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
		Local qs:String = TRackspaceCloudFiles.CreateQueryString(["limit=" + limit, "prefix=" + prefix, "marker=" + marker])
		Select Self._Transport(Self._storageUrl + qs)
			Case 200
				Local containerList:TList = New TList
				Local containerNames:String[] = Self._content.Split("~n")
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
		Select Self._Transport(Self._storageUrl + "/" + name, Null, "PUT")
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
		Select Self._Transport(Self._storageUrl, Null, "HEAD")
			Case 204
				Return String(Self._headers.ValueForKey("X-Account-Bytes-Used")).ToLong()
			Default
				Throw New TRackspaceCloudFilesException.SetMessage("Unable to handle response!")
		End Select
		Return 0
	End Method
	
'	Rem
'		bbdoc: Private method
'		about: Used to send requests. Sets header data and content data. Returns HTTP status code
'	End Rem
	Method _Transport:Int(url:String, headers:String[] = Null, requestMethod:String = "GET", userData:Object = Null)
		Self._headers.Clear()
		
		Local curl:TCurlEasy = TCurlEasy.Create()
		curl.setWriteString()
		curl.setOptInt(CURLOPT_VERBOSE, 0)
		curl.setOptInt(CURLOPT_FOLLOWLOCATION, 1)
		curl.setOptString(CURLOPT_CUSTOMREQUEST, requestMethod)
		curl.setOptString(CURLOPT_URL, url)
		
		'Use certificate bundle if set
		If TRackspaceCloudFiles.CAInfo
			curl.setOptString(CURLOPT_CAINFO, TRackspaceCloudFiles.CAInfo)
		'Otherwise don't check if SSL certificate is valid
		Else
			curl.setOptInt(CURLOPT_SSL_VERIFYPEER, False)
		End If
		
		'Pass content
		If userData
			Select requestMethod
				Case "POST"
					curl.setOptString(CURLOPT_POSTFIELDS, String(userData))
					curl.setOptLong(CURLOPT_POSTFIELDSIZE, String(userData).Length)
				Case "PUT"
					curl.setOptInt(CURLOPT_UPLOAD, True)
					Local stream:TStream = TStream(userData)
					curl.setOptLong(CURLOPT_INFILESIZE_LARGE, stream.Size())
					curl.setReadStream(stream)
			End Select
		End If
		
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
		
		curl.httpHeader(headerArray)
		
		curl.setHeaderCallback(Self.HeaderCallback, Self)
		
		Local res:Int = curl.perform()

		If TStream(userData)
			TStream(userData).Close()
		End If
				
		Local errorMessage:String
		If res Then
			errorMessage = CurlError(res)
		End If

		Local info:TCurlInfo = curl.getInfo()
		Local responseCode:Int = info.responseCode()

		curl.freeLists()
		curl.cleanup()
		
		Self._content = curl.toString()

		'Throw exception if an error with cURL occured
		If errorMessage <> Null
			Throw New TRackspaceCloudFilesException.SetMessage(errorMessage)
		End If
		
		Return responseCode
	End Method
	
	Rem
		bbdoc: Callback for cURL to catch headers
	End Rem
	Function HeaderCallback:Int(buffer:Byte Ptr, size:Int, data:Object)
		Local str:String = String.FromCString(buffer)
		
		Local parts:String[] = str.Split(":")
		If parts.Length >= 2
			TRackspaceCloudFiles(data)._headers.Insert(parts[0], str[parts[0].Length + 2..].Trim())
		End If
		
		Return size
	End Function
	
	Rem
		bbdoc: Create a query string from the given values
		about: Expects an array with strings. Each entry should be something like var=value
	End Rem
	Function CreateQueryString:String(params:String[])
		Local qs:String = "&".Join(params)
		If qs.Length > 0
			Return "?" + qs
		End If
		Return Null
	End Function
End Type

'Code below taken from the public domain
'http://www.blitzmax.com/codearcs/codearcs.php?code=1581
'Original author is Perturbatio/Kris Kelly

Function EncodeString:String(value:String, EncodeUnreserved:Int = False, UsePlusForSpace:Int = True)
	Local ReservedChars:String = "!*'();:@&=+$,/?%#[]~r~n"
	Local s:Int
	Local result:String

	For s = 0 To value.length - 1
		If ReservedChars.Find(value[s..s + 1]) > -1 Then
			result:+ "%"+ IntToHexString(Asc(value[s..s + 1]))
			Continue
		ElseIf value[s..s+1] = " " Then
			If UsePlusForSpace Then result:+"+" Else result:+"%20"
			Continue
		ElseIf EncodeUnreserved Then
				result:+ "%" + IntToHexString(Asc(value[s..s + 1]))
			Continue
		EndIf
		result:+ value[s..s + 1]
	Next

	Return result
End Function

Function DecodeString:String(EncStr:String)
	Local Pos:Int = 0
	Local HexVal:String
	Local Result:String

	While Pos<Len(EncStr)
		If EncStr[Pos..Pos+1] = "%" Then
			HexVal = EncStr[Pos+1..Pos+3]
			Result:+Chr(HexToInt(HexVal))
			Pos:+3
		ElseIf EncStr[Pos..Pos+1] = "+" Then
			Result:+" "
			Pos:+1
		Else
			Result:+EncStr[Pos..Pos + 1]
			Pos:+1	
		EndIf
	Wend
	
	Return Result
End Function


Function HexToInt:Int( HexStr:String )
	If HexStr.Find("$") <> 0 Then HexStr = "$" + HexStr
	Return Int(HexStr)
End Function


Function IntToHexString:String(val:Int, chars:Int = 2)
	Local Result:String = Hex(val)
	Return result[result.length-chars..]
End Function
