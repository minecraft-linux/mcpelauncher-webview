/*
 * Native macOS WKWebView implementation of mcpelauncher-webview.
 *
 * Uses the system WebKit engine (Safari) instead of Qt WebEngine (Chromium).
 * This solves two problems on modern macOS:
 *   1. The bundled Qt WebEngine uses Chrome 75 (2019), which cannot
 *      negotiate TLS with Microsoft's Xbox Live auth servers.
 *   2. Qt WebEngine is x86_64-only in the current macOS builds,
 *      adding unnecessary Rosetta overhead on Apple Silicon.
 *
 * Interface: mcpelauncher-webview <startUrl> <endUrl>
 *   Opens startUrl in a WKWebView window. When navigation reaches a
 *   URL starting with endUrl, prints the full URL to stdout and exits.
 *   This matches the existing Qt implementation's behavior exactly.
 */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface WebViewDelegate : NSObject <WKNavigationDelegate, NSWindowDelegate>
@property (nonatomic, strong) NSString *endUrl;
@end

@implementation WebViewDelegate

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {

    NSString *url = navigationAction.request.URL.absoluteString;

    if (self.endUrl && [url hasPrefix:self.endUrl]) {
        printf("%s\n", [url UTF8String]);
        fflush(stdout);
        decisionHandler(WKNavigationActionPolicyCancel);
        [NSApp terminate:nil];
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
    decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
    withError:(NSError *)error {
    /* Custom URL schemes (e.g. ms-xal-*://) trigger a provisional
       navigation failure because WKWebView cannot load them directly.
       Check if the failing URL matches endUrl. */
    NSURL *failingURL = error.userInfo[NSURLErrorFailingURLErrorKey];
    NSString *url = failingURL.absoluteString;
    if (url && self.endUrl && [url hasPrefix:self.endUrl]) {
        printf("%s\n", [url UTF8String]);
        fflush(stdout);
        [NSApp terminate:nil];
        return;
    }
    fprintf(stderr, "[webview] Navigation failed: %s\n",
            [[error localizedDescription] UTF8String]);
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [NSApp terminate:nil];
    return YES;
}

@end

int main(int argc, const char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <startUrl> <endUrl>\n", argv[0]);
        return 1;
    }

    NSString *startUrl = [NSString stringWithUTF8String:argv[1]];
    NSString *endUrl = [NSString stringWithUTF8String:argv[2]];

    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        /* Standard menu bar with Edit menu for copy/paste support */
        NSMenu *menuBar = [[NSMenu alloc] init];

        NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
        NSMenu *appMenu = [[NSMenu alloc] init];
        [appMenu addItemWithTitle:@"Quit"
                           action:@selector(terminate:)
                    keyEquivalent:@"q"];
        [appMenuItem setSubmenu:appMenu];
        [menuBar addItem:appMenuItem];

        NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
        NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
        [editMenu addItemWithTitle:@"Undo"
                            action:@selector(undo:)
                     keyEquivalent:@"z"];
        [editMenu addItemWithTitle:@"Redo"
                            action:@selector(redo:)
                     keyEquivalent:@"Z"];
        [editMenu addItem:[NSMenuItem separatorItem]];
        [editMenu addItemWithTitle:@"Cut"
                            action:@selector(cut:)
                     keyEquivalent:@"x"];
        [editMenu addItemWithTitle:@"Copy"
                            action:@selector(copy:)
                     keyEquivalent:@"c"];
        [editMenu addItemWithTitle:@"Paste"
                            action:@selector(paste:)
                     keyEquivalent:@"v"];
        [editMenu addItemWithTitle:@"Select All"
                            action:@selector(selectAll:)
                     keyEquivalent:@"a"];
        [editMenuItem setSubmenu:editMenu];
        [menuBar addItem:editMenuItem];

        [NSApp setMainMenu:menuBar];

        /* Size the window to 80% of the screen, centered */
        NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
        CGFloat w = screenFrame.size.width * 0.8;
        CGFloat h = screenFrame.size.height * 0.8;
        CGFloat x = screenFrame.origin.x + (screenFrame.size.width - w) / 2;
        CGFloat y = screenFrame.origin.y + (screenFrame.size.height - h) / 2;
        NSRect frame = NSMakeRect(x, y, w, h);

        NSWindow *window = [[NSWindow alloc]
            initWithContentRect:frame
            styleMask:(NSWindowStyleMaskTitled |
                       NSWindowStyleMaskClosable |
                       NSWindowStyleMaskResizable |
                       NSWindowStyleMaskMiniaturizable)
            backing:NSBackingStoreBuffered
            defer:NO];
        [window setTitle:@"Sign in to Minecraft"];

        /* WKWebView with persistent data store (remembers sessions) */
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];

        WKWebView *webView = [[WKWebView alloc]
            initWithFrame:window.contentView.bounds
            configuration:config];
        webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        WebViewDelegate *delegate = [[WebViewDelegate alloc] init];
        delegate.endUrl = endUrl;

        webView.navigationDelegate = delegate;
        window.delegate = delegate;
        window.contentView = webView;

        NSURL *url = [NSURL URLWithString:startUrl];
        [webView loadRequest:[NSURLRequest requestWithURL:url]];

        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }

    return 0;
}
