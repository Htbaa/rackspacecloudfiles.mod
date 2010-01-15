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
