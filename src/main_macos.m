/*
 * Native WKWebView replacement for mcpelauncher-webview.
 * Uses Safari's engine (always current) instead of Chrome 75.
 *
 * Usage: webview_native <startUrl> <endUrl>
 * Opens startUrl in a WKWebView. When navigation reaches a URL
 * that starts with endUrl, prints the full URL to stdout and exits.
 */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface WebViewDelegate : NSObject <WKNavigationDelegate, NSWindowDelegate>
@property (nonatomic, strong) NSString *endUrl;
@property (nonatomic, assign) BOOL done;
@end

@implementation WebViewDelegate

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {

    NSString *url = navigationAction.request.URL.absoluteString;

    if (self.endUrl && [url hasPrefix:self.endUrl]) {
        /* Print the final URL (with tokens) to stdout */
        printf("%s\n", [url UTF8String]);
        fflush(stdout);
        self.done = YES;
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
    didFailNavigation:(WKNavigation *)navigation
    withError:(NSError *)error {
    fprintf(stderr, "[webview] Navigation failed: %s\n",
            [[error localizedDescription] UTF8String]);
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
    withError:(NSError *)error {
    /* Handle custom URL schemes (ms-xal-*://) that WKWebView can't load */
    NSString *url = error.userInfo[NSURLErrorFailingURLStringErrorKey];
    if (url && self.endUrl && [url hasPrefix:self.endUrl]) {
        printf("%s\n", [url UTF8String]);
        fflush(stdout);
        self.done = YES;
        [NSApp terminate:nil];
        return;
    }
    fprintf(stderr, "[webview] Provisional navigation failed: %s\n",
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

        /* Menu bar with Edit menu for copy/paste */
        NSMenu *menuBar = [[NSMenu alloc] init];
        NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
        NSMenu *appMenu = [[NSMenu alloc] init];
        [appMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
        [appMenuItem setSubmenu:appMenu];
        [menuBar addItem:appMenuItem];

        NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
        NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
        [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
        [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
        [editMenu addItem:[NSMenuItem separatorItem]];
        [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
        [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
        [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
        [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
        [editMenuItem setSubmenu:editMenu];
        [menuBar addItem:editMenuItem];

        [NSApp setMainMenu:menuBar];

        /* Create window */
        NSRect frame = NSMakeRect(0, 0, 480, 640);
        NSWindow *window = [[NSWindow alloc]
            initWithContentRect:frame
            styleMask:(NSWindowStyleMaskTitled |
                       NSWindowStyleMaskClosable |
                       NSWindowStyleMaskResizable)
            backing:NSBackingStoreBuffered
            defer:NO];
        [window setTitle:@"Sign in to Minecraft"];
        [window center];

        /* Configure WKWebView */
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];

        WKWebView *webView = [[WKWebView alloc] initWithFrame:frame
                                                 configuration:config];

        WebViewDelegate *delegate = [[WebViewDelegate alloc] init];
        delegate.endUrl = endUrl;
        delegate.done = NO;

        webView.navigationDelegate = delegate;
        window.delegate = delegate;
        window.contentView = webView;

        /* Load the start URL */
        NSURL *url = [NSURL URLWithString:startUrl];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [webView loadRequest:request];

        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }

    return 0;
}
