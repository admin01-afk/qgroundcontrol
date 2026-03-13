#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <memory>

class RosBridgeNode : public QObject
{
    Q_OBJECT

public:
    // singleton accessor (definition in .cc)
    static RosBridgeNode* instance();

    explicit RosBridgeNode(QObject* parent = nullptr);
    ~RosBridgeNode();

    // have service_names here, not in qml
    Q_INVOKABLE void startYolo() { callService("/start_yolo"); }
    Q_INVOKABLE void stopYolo() { callService("/stop_yolo"); }

    Q_INVOKABLE void startNavigation() { callService("/start_navigation"); }
    Q_INVOKABLE void stopNavigation() {callService("/stop_navigation"); }

    Q_INVOKABLE void startVisualTrack() { callService("/start_visual_track"); }
    Q_INVOKABLE void stopVisualTrack() { callService("/stop_visual_track"); }



    Q_INVOKABLE void callService(const QString& serviceName);

signals:
    // emitted on Qt main thread when a service call returns
    void serviceResult(const QString &serviceName, bool success, const QString &message);

private:
    // Use opaque pointers to ROS implementation to avoid MOC template instantiation issues
    class RosImpl;
    std::unique_ptr<RosImpl> _impl;
};
