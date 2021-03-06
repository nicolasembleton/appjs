#import  <Cocoa/Cocoa.h>
#include "include/cef_browser.h"
#include "includes/cef.h"
#include "includes/cef_handler.h"

CefWindowHandle ClientHandler::GetMainHwnd(){
  return m_MainHwnd;
}

void ClientHandler::OnTitleChange(CefRefPtr<CefBrowser> browser,
                                  const CefString& title)
{
  REQUIRE_UI_THREAD();

  // Set the frame window title bar
  NSView* view = (NSView*)browser->GetWindowHandle();
  NSWindow* window = [view window];
  std::string titleStr(title);
  NSString* str = [NSString stringWithUTF8String:titleStr.c_str()];
  [window setTitle:str];
}

void ClientHandler::OnContentsSizeChange(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame, 
                                    int width, 
                                    int height)
{
  REQUIRE_UI_THREAD();

  if(this->m_AutoResize) {
    // Size the window.
    NSView* view = (NSView*)browser->GetWindowHandle();
    NSWindow* window = [view window];
    NSRect r = [window contentRectForFrameRect:[window frame]];
    r.size.width = width;
    r.size.height = height;
    [window setFrame:[window frameRectForContentRect:r] display:YES];
  }
}
void ClientHandler::CloseMainWindow() {
  
  REQUIRE_UI_THREAD();
  appjs::Cef::Shutdown();
}

CefRefPtr<ClientHandler> g_handler;
