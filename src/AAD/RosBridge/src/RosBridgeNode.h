#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtGui/QImage>
#include <memory>

#ifdef ROSBRIDGE_ENABLE_ROS
#include <rclcpp/rclcpp.hpp>
#include <std_srvs/srv/trigger.hpp>
#include "sensor_msgs/msg/image.hpp"
#endif

class RosBridgeNode : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int imageRevision READ imageRevision NOTIFY imageRevisionChanged)

public:
    // singleton accessor (definition in .cc)
    static RosBridgeNode* instance();

    explicit RosBridgeNode(QObject* parent = nullptr);
    ~RosBridgeNode();

    // have service_names here, not in qml
    Q_INVOKABLE int startYolo() { return callService("/plane1/start_yolo"); }
    Q_INVOKABLE int stopYolo() { return callService("/plane1/stop_yolo"); }

    Q_INVOKABLE int startNavigation() { return callService("start_navigation"); }
    Q_INVOKABLE int stopNavigation() { return callService("stop_navigation"); }

    Q_INVOKABLE int startVisualTrack() { return callService("start_visual_track"); }
    Q_INVOKABLE int stopVisualTrack() { return callService("stop_visual_track"); }

    Q_INVOKABLE int callService(const QString& serviceName);

    Q_INVOKABLE void subscribeImageTopic(const QString& topicName);
    QImage latestImage() const;

    int imageRevision() const { return _imageRevision; }

signals:
    // emitted on Qt main thread when a service call returns
    void serviceResult(int requestId, bool success, const QString &message);
    void imageRevisionChanged();

private:
    // Use opaque pointers to ROS implementation to avoid MOC template instantiation issues
    class RosImpl;
    std::unique_ptr<RosImpl> _impl;

    int _imageRevision = 0;

#ifdef ROSBRIDGE_ENABLE_ROS
    using TriggerClient = rclcpp::Client<std_srvs::srv::Trigger>;

    std::shared_ptr<TriggerClient>
    getOrCreateTriggerClient(const std::string& serviceName);
#endif
};
