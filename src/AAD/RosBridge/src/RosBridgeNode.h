#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtGui/QImage>

#include <list>
#include <memory>
#include <string>

#ifdef ROSBRIDGE_ENABLE_ROS
#include <rclcpp/rclcpp.hpp>
#include <std_srvs/srv/trigger.hpp>
#include "sensor_msgs/msg/image.hpp"
#include "savasan_general/msg/guidance_info.hpp"
#include "savasan_general/msg/no_fly_zone.hpp"
#include "savasan_general/srv/set_kamikaze_params.hpp"
#include "savasan_general/srv/konum_handling_config.hpp"
#include "mavros_msgs/srv/command_long.hpp"
#include <unordered_map>
#endif

class RosBridgeNode : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList image_topics READ getImageTopics NOTIFY imageTopicsChanged)
    Q_PROPERTY(QString selectedImageTopic READ selectedImageTopic WRITE setSelectedImageTopic NOTIFY selectedImageTopicChanged)
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

    Q_INVOKABLE int startKamikaze() { return callService("/plane1/start_kamikaze"); }
    Q_INVOKABLE int abortKamikaze() { return callService("/plane1/abort_kamikaze"); }

    Q_INVOKABLE int setKamikazeParams(double pullUpAltitude, double approachHeadingDeg,
                                    double diveAngleDeg, double climbBufferDistance,
                                    bool setAdvancedParams, double diveStartAltitude,
                                    double maxDiveAngleDeg, double minDiveAngleDeg,
                                    double maxRollAngleDeg, double rollDeadbandDeg,
                                    double rollPGain);

    Q_INVOKABLE int setKonumHandlingConfig(int target, bool fixed_target);

    Q_INVOKABLE int startRecording() { return callService("/plane1/start_recording"); }
    Q_INVOKABLE int stopRecording() { return callService("/plane1/stop_recording"); }

    Q_INVOKABLE int callService(const QString& serviceName);

    QImage latestImage() const;

    // Publish KonumBilgileri array to ROS topic
    void publishKonumBilgileri(const QJsonArray& konumArray);

    // Publish No-Fly Zones to ROS topic and upload geofences to UAV
    void publishNoFlyZones(const QJsonArray& hssArray);

    // Send guidance command to ROS topic
    Q_INVOKABLE void sendGuidanceCommand(int command, bool force = false);

    Q_INVOKABLE void setSelectedImageTopic(const QString& topic);
    Q_INVOKABLE void addImageTopic(const QString& topic);
    Q_INVOKABLE void removeImageTopic(const QString& topic);

    int imageRevision() const { return _imageRevision; }
    QString currentMode() const { return _currentMode; }
    bool modeLock() const { return _modeLock; }
    QStringList methodNames() const { return _methodNames; }
    QList<bool> methodAuths() const { return _methodAuths; }

    QStringList getImageTopics() const { return _image_topics; }
    QString selectedImageTopic() const;

signals:
    // emitted on Qt main thread when a service call returns
    void serviceResult(int requestId, bool success, const QString &message);
    void imageRevisionChanged();
    void currentModeChanged();
    void modeLockChanged();
    void methodNamesChanged();
    void methodAuthsChanged();
    void imageTopicsChanged();
    void selectedImageTopicChanged();

private:
    // Use opaque pointers to ROS implementation to avoid MOC template instantiation issues
    class RosImpl;
    std::unique_ptr<RosImpl> _impl;

    QStringList _image_topics = {"/plane1/image_processed", "test", "/test/image", "/plane1/image_processed"};
    int _imageRevision = 0;
    QString _currentMode = "";
    bool _modeLock = false;
    QStringList _methodNames;
    QList<bool> _methodAuths;

#ifdef ROSBRIDGE_ENABLE_ROS
    using TriggerClient = rclcpp::Client<std_srvs::srv::Trigger>;
    using CommandLongClient = rclcpp::Client<mavros_msgs::srv::CommandLong>;
    using SetKamikazeParamsClient = rclcpp::Client<savasan_general::srv::SetKamikazeParams>;
    using KonumHandlingConfigClient = rclcpp::Client<savasan_general::srv::KonumHandlingConfig>;

    template<typename ServiceT>
    std::shared_ptr<rclcpp::Client<ServiceT>>
    getOrCreateClient(
        std::shared_ptr<rclcpp::Client<ServiceT>>& client,
        const std::string& serviceName);

    template<typename ServiceT>
    std::shared_ptr<rclcpp::Client<ServiceT>>
    getOrCreateClient(
        std::unordered_map<std::string, std::shared_ptr<rclcpp::Client<ServiceT>>>& clients,
        const std::string& serviceName);

    void clearGeofences();
    void uploadGeofence(double latitude, double longitude, double radius);
    void geofenceResponseCallback(int geofenceId, bool isClear);

    void guidanceInfoCallback(savasan_general::msg::GuidanceInfo::SharedPtr msg);

    void createImageSubscription(const QString& topic);
    void removeImageSubscription(const QString& topic);
#endif
};
