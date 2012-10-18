<!-- #include file="upload.asp" -->
<!-- #include file="ioelmsrv.vbscript.asp" -->

<%

' Create the FileUploader
Dim uplr, File
Set uplr= New FileUploader

' This starts the upload process
uplr.Upload()

Call wsAddVariable("name",uplr.Form("name"))
Call wsAddVariable("color",uplr.Form("color"))

For Each File In uplr.Files.Items 
	Call wsAddVariable("file",File.FileName)
	Call wsAddVariable("size",File.FileSize)
Next

Call wsDispatchVariables()



%>