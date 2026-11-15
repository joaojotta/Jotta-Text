/* Windows Common Item Dialogs. UTF-8 stdout, status 2 means Cancel. */
#define COBJMACROS
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <shobjidl.h>
#include <shellapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>
#include <io.h>
#include <fcntl.h>

int wmain(int argc, wchar_t **argv) {
  if (argc == 3 && (!wcscmp(argv[1], L"uri") || !wcscmp(argv[1],L"github-uri"))) {
    const wchar_t *prefix=!wcscmp(argv[1],L"github-uri")?L"https://github.com/":L"http://127.0.0.1:";
    if (wcsncmp(argv[2],prefix,wcslen(prefix))) return 1;
    return (INT_PTR)ShellExecuteW(NULL,L"open",argv[2],NULL,NULL,SW_SHOWNORMAL)>32 ? 0:1;
  }
  if (argc<2 || (wcscmp(argv[1],L"file") && wcscmp(argv[1],L"folder") && wcscmp(argv[1],L"save"))) return 1;
  HRESULT hr=CoInitializeEx(NULL,COINIT_APARTMENTTHREADED|COINIT_DISABLE_OLE1DDE);
  if (FAILED(hr)) return 1;
  int status=1;
  BOOL save=!wcscmp(argv[1],L"save"),folder=!wcscmp(argv[1],L"folder");
  BOOL portuguese=argc>4 && !wcscmp(argv[4],L"pt-PT");
  IFileDialog *dialog=NULL;
  hr=CoCreateInstance(save?&CLSID_FileSaveDialog:&CLSID_FileOpenDialog,NULL,CLSCTX_INPROC_SERVER,&IID_IFileDialog,(void**)&dialog);
  if (SUCCEEDED(hr)) {
    FILEOPENDIALOGOPTIONS options=0;
    IFileDialog_GetOptions(dialog,&options);
    IFileDialog_SetOptions(dialog,options|FOS_FORCEFILESYSTEM|FOS_PATHMUSTEXIST|FOS_NOCHANGEDIR|
      (folder?FOS_PICKFOLDERS:save?FOS_OVERWRITEPROMPT:FOS_FILEMUSTEXIST));
    IFileDialog_SetTitle(dialog,portuguese?(save?L"Guardar ficheiro":folder?L"Abrir pasta":L"Abrir ficheiro"):
      (save?L"Save File":folder?L"Open Folder":L"Open File"));
    if (portuguese) IFileDialog_SetOkButtonLabel(dialog,save?L"Guardar":L"Abrir");
    if (argc>2 && *argv[2]) {
      IShellItem *initial=NULL;
      if (SUCCEEDED(SHCreateItemFromParsingName(argv[2],NULL,&IID_IShellItem,(void**)&initial))) {
        IFileDialog_SetFolder(dialog,initial);IShellItem_Release(initial);
      }
    }
    if (save && argc>3 && *argv[3]) IFileDialog_SetFileName(dialog,argv[3]);
    hr=IFileDialog_Show(dialog,NULL);
    if (hr==HRESULT_FROM_WIN32(ERROR_CANCELLED)) status=2;
    else if (SUCCEEDED(hr)) {
      IShellItem *item=NULL;
      if (SUCCEEDED(IFileDialog_GetResult(dialog,&item))) {
        PWSTR path=NULL;
        if (SUCCEEDED(IShellItem_GetDisplayName(item,SIGDN_FILESYSPATH,&path))) {
          int size=WideCharToMultiByte(CP_UTF8,0,path,-1,NULL,0,NULL,NULL);
          char *utf8=size>0?malloc(size):NULL;
          if (utf8 && WideCharToMultiByte(CP_UTF8,0,path,-1,utf8,size,NULL,NULL)) {
            _setmode(_fileno(stdout),_O_BINARY);
            status=fwrite(utf8,1,size-1,stdout)==(size_t)size-1 && fflush(stdout)==0?0:1;
          }
          free(utf8);CoTaskMemFree(path);
        }
        IShellItem_Release(item);
      }
    }
    IFileDialog_Release(dialog);
  }
  if (status==1) fprintf(stderr,"Windows file dialog failed (HRESULT 0x%08lx)\n",(unsigned long)hr);
  CoUninitialize();
  return status;
}
