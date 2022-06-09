import QtQuick
import QtQuick.Controls
import QtWebEngine
import QtQuick.Layouts

ApplicationWindow {
    visible: true
    x: initialX
    y: initialY
    width: initialWidth
    height: initialHeight
    title: webEngineView.title

    WebEngineView {
        id: webEngineView
        anchors.fill: parent
        url: startUrl
    }
}