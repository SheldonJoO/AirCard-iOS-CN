//
//  RespringHelper.swift
//  AirCard-iOS
//
//  基于 NeoSpring 实现的重启界面与 PosterBoard 刷新（作者 @neonmodder123 & @skadz108）。
//

import UIKit
import Foundation
import WebKit
import SwiftUI
import AirliftFFI

public final class RespringHelper: NSObject {

    public static let neospringHTML = """
<!DOCTYPE html>
<html>
    <body>
        <!-- big credit to @neonmodder123 & @skadz108 (neospring) -->
        <iframe id="frame" srcdoc="" sandbox="allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-popups allow-presentation allow-scripts"></iframe>
        <script>
            const frame = document.getElementById('frame');
            const funfun = `
                <html>
                <body>
                    <script>
                        const container = document.createElement('div');
                        container.style.cssText = 'perspective: 1px; perspective-origin: 9999999% 9999999%;';
                        document.body.appendChild(container);
    
                        for (let i = 0; i < 500; i++) {
                            let d = document.createElement('div');
                            d.style.cssText = 'position: absolute; width: 100vw; height: 100vh; backdrop-filter: blur(100px); -webkit-backdrop-filter: blur(100px); transform: translate3d(100000px, 100000px, ' + i + 'px) rotateY(90deg);';
                            container.appendChild(d);
                        }
    
                        setInterval(() => {
                            navigator.share({ title: 'R', text: 'R'.repeat(100000) }).catch(() => {});
                            let x = new Uint8Array(1024 * 1024 * 10);
                            crypto.getRandomValues(x);
                        }, 0);
                    <\\/script>
                </body>
                </html>
            `;
    
            frame.srcdoc = funfun;
        </script>
    </body>
</html>
"""


    /// 直接打开「设置 › 墙纸」，让用户立即选择刚注入的合集壁纸
    public static func openWallpaperSettings() {
        for urlStr in ["prefs:root=WALLPAPER", "App-prefs:root=WALLPAPER", "prefs:root=Wallpaper", UIApplication.openSettingsURLString] {
            if let url = URL(string: urlStr) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }
        }
    }

    /// 通过在主窗口上附加一个全屏 WKWebView，直接触发 NeoSpring
    public static func triggerNeoSpring() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
                return
            }
            let config = WKWebViewConfiguration()
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            let webView = WKWebView(frame: window.bounds, configuration: config)
            webView.isOpaque = true
            webView.backgroundColor = .black
            window.addSubview(webView)
            webView.loadHTMLString(neospringHTML, baseURL: nil)
        }
    }
}

/// NeoSpring WKWebView 的 SwiftUI 封装，实现参考 rooootdev/neospring
public struct NeoSpringView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(RespringHelper.neospringHTML, baseURL: nil)
    }
}
