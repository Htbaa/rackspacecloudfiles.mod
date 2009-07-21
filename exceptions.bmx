Rem
	bbdoc: Exception for TRackspaceCloudFiles
End Rem
Type TRackspaceCloudBaseException Abstract
	Field message:String
	
	Rem
		bbdoc: Sets message
	End Rem
	Method SetMessage:TRackspaceCloudBaseException(message:String)
		Self.message = message
		Return Self
	End Method
	
	Rem
		bbdoc: Return message
	End Rem
	Method ToString:String()
		Return Self.message
	End Method
End Type

Rem
	bbdoc: Exception for TRackspaceCloudFiles
End Rem
Type TRackspaceCloudFilesException Extends TRackspaceCloudBaseException
End Type

Rem
	bbdoc: Exception for TRackspaceCloudFilesContainer
End Rem
Type TRackspaceCloudFilesContainerException Extends TRackspaceCloudBaseException
End Type

Rem
	bbdoc: Exception for TRackspaceCloudFileObject
End Rem
Type TRackspaceCloudFileObjectException Extends TRackspaceCloudBaseException
End Type
