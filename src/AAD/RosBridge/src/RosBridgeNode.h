#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtGui/QImage>
#include <memory>

#ifdef ROSBRIDGE_ENABLE_ROS
#include <rclcpp/rclcpp.hpp>
#include <std_srvs/srv/trigger.hpp>
#include "sensor_msgs/msg/image.hpp"
#include "savasan_general/msg/guidance_info.hpp"
#include "savasan_general/msg/no_fly_zone.hpp"
#include "mavros_msgs/srv/command_long.hpp"
#endif

class RosBridgeNode : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int imageRevision READ imageRevision NOTIFY imageRevisionChanged)
    Q_PROPERTY(QString currentMode READ currentMode NOTIFY currentModeChanged)
    Q_PROPERTY(bool modeLock READ modeLock NOTIFY modeLockChanged)
    Q_PROPERTY(QStringList methodNames READ methodNames NOTIFY methodNamesChanged)
    Q_PROPERTY(QList<bool> methodAuths READ methodAuths NOTIFY methodAuthsChanged)

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

    Q_INVOKABLE int startKamikaze() { return callService("/plane1/start_kamikaze"); }
    Q_INVOKABLE int abortKamikaze() { return callService("/plane1/abort_kamikaze"); }

    Q_INVOKABLE int startRecording() { return callService("/plane1/start_recording"); }
    Q_INVOKABLE int stopRecording() { return callService("/plane1/stop_recording"); }

    Q_INVOKABLE int callService(const QString& serviceName);

    Q_INVOKABLE void subscribeImageTopic(const QString& topicName);
    QImage latestImage() const;

    // Publish KonumBilgileri array to ROS topic
    void publishKonumBilgileri(const QJsonArray& konumArray);

    // Publish No-Fly Zones to ROS topic and upload geofences to UAV
    void publishNoFlyZones(const QJsonArray& hssArray);

    // Send guidance command to ROS topic
    Q_INVOKABLE void sendGuidanceCommand(int command, bool force = false);

    int imageRevision() const { return _imageRevision; }
    QString currentMode() const { return _currentMode; }
    bool modeLock() const { return _modeLock; }
    QStringList methodNames() const { return _methodNames; }
    QList<bool> methodAuths() const { return _methodAuths; }

signals:
    // emitted on Qt main thread when a service call returns
    void serviceResult(int requestId, bool success, const QString &message);
    void imageRevisionChanged();
    void currentModeChanged();
    void modeLockChanged();
    void methodNamesChanged();
    void methodAuthsChanged();

private:
    // Use opaque pointers to ROS implementation to avoid MOC template instantiation issues
    class RosImpl;
    std::unique_ptr<RosImpl> _impl;

    int _imageRevision = 0;
    QString _currentMode = "";
    bool _modeLock = false;
    QStringList _methodNames;
    QList<bool> _methodAuths;

#ifdef ROSBRIDGE_ENABLE_ROS
    using TriggerClient = rclcpp::Client<std_srvs::srv::Trigger>;
    using CommandLongClient = rclcpp::Client<mavros_msgs::srv::CommandLong>;

    std::shared_ptr<TriggerClient>
    getOrCreateTriggerClient(const std::string& serviceName);

    std::shared_ptr<CommandLongClient>
    getOrCreateCommandLongClient(const std::string& serviceName);

    void clearGeofences();
    void uploadGeofence(double latitude, double longitude, double radius);
    void geofenceResponseCallback(int geofenceId, bool isClear);

    void guidanceInfoCallback(savasan_general::msg::GuidanceInfo::SharedPtr msg);
#endif
};
