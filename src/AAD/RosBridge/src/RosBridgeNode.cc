#include "RosBridgeNode.h"

#include <QCoreApplication>
#include <QDebug>
#include <QJsonDocument>
#include <QMetaObject>
#include <QNetworkAccessManager>
#include <QSettings>

#include <functional>
#include <mutex>
#include <thread>
#include <unordered_map>

#include "server/ServerManager.h"

#ifdef ROSBRIDGE_ENABLE_ROS
#include <QJsonArray>
#include <QJsonObject>
#include <QtGui/QImage>

#include "mavros_msgs/srv/command_long.hpp"
#include "rclcpp/rclcpp.hpp"
#include "savasan_general/msg/guidance_command.hpp"
#include "savasan_general/msg/guidance_info.hpp"
#include "savasan_general/msg/konum_bilgileri.hpp"
#include "savasan_general/msg/konum_bilgisi.hpp"
#include "savasan_general/msg/no_fly_zone.hpp"
#include "savasan_general/msg/no_fly_zone_array.hpp"
#include "savasan_general/srv/konum_handling_config.hpp"
#include "savasan_general/srv/send_lock.hpp"
#include "savasan_general/srv/send_qr.hpp"
#include "savasan_general/srv/set_kamikaze_params.hpp"
#include "sensor_msgs/msg/image.hpp"
#include "std_srvs/srv/trigger.hpp"
#endif

static QImage rosImageToQImage(const sensor_msgs::msg::Image& msg);

// Only include ROS headers if available and enabled (for colcon/QGC build with ROS)
#ifdef ROSBRIDGE_ENABLE_ROS
class RosBridgeNode::RosImpl
{
public:
    std::shared_ptr<rclcpp::Node> node;
    std::shared_ptr<rclcpp::Executor> executor;
    std::thread spinThread;

    std::mutex clientMutex;
    std::unordered_map<std::string, std::shared_ptr<TriggerClient>> triggerClients;
    std::unordered_map<std::string, std::shared_ptr<CommandLongClient>> commandLongClients;

    std::mutex imageMutex;
    std::list<std::shared_ptr<rclcpp::Subscription<sensor_msgs::msg::Image>>> imageSubs;
    std::unordered_map<std::string, std::shared_ptr<rclcpp::Subscription<sensor_msgs::msg::Image>>> imageSubsMap;
    std::string selectedImageTopic = "/plane1/image_processed";
    std::mutex selectedTopicMutex;
    QImage latestImage;

    // Guidance
    rclcpp::Subscription<savasan_general::msg::GuidanceInfo>::SharedPtr guidanceInfoSub;
    rclcpp::Publisher<savasan_general::msg::GuidanceCommand>::SharedPtr guidanceCmdPub;

    std::shared_ptr<rclcpp::Publisher<savasan_general::msg::KonumBilgileri>> konumPub;
    std::shared_ptr<rclcpp::Publisher<savasan_general::msg::NoFlyZoneArray>> nfzPub;

    std::atomic<int> nextRequestId{1};
    std::atomic<int> nextGeofenceId{1};

    rclcpp::Service<savasan_general::srv::SendLock>::SharedPtr send_lock_message;
    rclcpp::Service<savasan_general::srv::SendQR>::SharedPtr send_qr_message;

    // kamikaze
    rclcpp::Service<TriggerClient>::SharedPtr start_kamikaze;
    rclcpp::Service<TriggerClient>::SharedPtr abort_kamikaze;

    std::shared_ptr<SetKamikazeParamsClient> setKamikazeParamsClient;
    std::shared_ptr<KonumHandlingConfigClient> konumHandlingConfigClient;
};
#else
class RosBridgeNode::RosImpl
{
public:
};
#endif
#ifdef ROSBRIDGE_ENABLE_ROS

// Generic template for single clients
template <typename ServiceT>
std::shared_ptr<rclcpp::Client<ServiceT>> RosBridgeNode::getOrCreateClient(
    std::shared_ptr<rclcpp::Client<ServiceT>>& client, const std::string& serviceName)
{
    std::lock_guard<std::mutex> lock(_impl->clientMutex);

    if (client) {
        return client;
    }

    client = _impl->node->create_client<ServiceT>(serviceName);
    return client;
}

// Generic template for map-based clients (multiple service names)
template <typename ServiceT>
std::shared_ptr<rclcpp::Client<ServiceT>> RosBridgeNode::getOrCreateClient(
    std::unordered_map<std::string, std::shared_ptr<rclcpp::Client<ServiceT>>>& clients, const std::string& serviceName)
{
    std::lock_guard<std::mutex> lock(_impl->clientMutex);

    auto it = clients.find(serviceName);
    if (it != clients.end()) {
        return it->second;
    }

    auto client = _impl->node->create_client<ServiceT>(serviceName);
    clients.emplace(serviceName, client);
    return client;
}

#endif
static RosBridgeNode* _instance = nullptr;

RosBridgeNode* RosBridgeNode::instance()
{
    if (!_instance) {
        _instance = new RosBridgeNode();
    }
    return _instance;
}

// Service callback for send_lock_message - receives lock timing data
void send_lock_message_callback(const std::shared_ptr<savasan_general::srv::SendLock::Request> request,
                                std::shared_ptr<savasan_general::srv::SendLock::Response> response)
{
    /*
        Örnek Kilitlenme Verisi - SIHA_Haberlesme_Dokumani_2026
        POST /api/kilitlenme_bilgisi
        {
            "kilitlenmeBitisZamani":
                { "saat": 11,
                "dakika": 41,
                "saniye": 03,
                "milisaniye": 141
                },
            "otonom_kilitlenme": 1
        }
    */
    try {
        QJsonObject data_dict;
        data_dict["kilitlenmeBitisZamani"] = QJsonObject{
            {"saat", request->data.stop_hour},
            {"dakika", request->data.stop_min},
            {"saniye", request->data.stop_second},
            {"milisaniye", request->data.stop_milisecond},
        };
        data_dict["otonom_kilitlenme"] = request->data.otonom;

        qDebug() << "[RosBridgeNode] send_lock_message srv received!";
        qDebug() << "[RosBridgeNode] Lock payload:" << QJsonDocument(data_dict).toJson(QJsonDocument::Compact);

        auto promise = std::make_shared<std::promise<bool>>();
        auto future = promise->get_future();

        QMetaObject::invokeMethod(
            ServerManager::instance(),
            [data_dict, promise]() {
                ServerManager::instance()->sendJsonRequestAsync(QNetworkAccessManager::PostOperation,
                                                                "/api/kilitlenme_bilgisi", data_dict,
                                                                [promise](bool ok) { promise->set_value(ok); });
            },
            Qt::QueuedConnection);

        bool ok = future.get();

        response->success = ok;
        response->result = ok ? 200 : 400;

        if (ok) {
            qDebug() << "[RosBridgeNode] Lock data sent to server successfully";
        } else {
            qWarning() << "[RosBridgeNode] Server rejected lock data";
        }
    } catch (const std::exception& e) {
        qWarning() << "[RosBridgeNode] Error in send_lock_message_callback:" << e.what();
        response->success = false;
        response->result = 400;
    }
}

void send_qr_message_callback(const std::shared_ptr<savasan_general::srv::SendQR::Request> request,
                              std::shared_ptr<savasan_general::srv::SendQR::Response> response)
{
    /*
        Örnek Kamikaze Verisi - SIHA_Haberlesme_Dokumani_2026
        POST /api/kamikaze_bilgisi
        {
            "kamikazeBaslangicZamani"
                : { "saat": 11,
                "dakika": 44,
                "saniye": 13,
                "milisaniye": 361
            },
            "kamikazeBitisZamani":
                { "saat": 11,
                "dakika": 44,
                "saniye": 27,
                "milisaniye": 874
            },
            "qrMetni ": “teknofest2025”
        }
    */
    try {
        QJsonObject data_dict;
        data_dict["kilitlenmeBaslangicZamani"] = QJsonObject{
            {"saat", request->data.start_hour},
            {"dakika", request->data.start_min},
            {"saniye", request->data.start_second},
            {"milisaniye", request->data.start_milisecond},
        };
        data_dict["kilitlenmeBitisZamani"] = QJsonObject{
            {"saat", request->data.stop_hour},
            {"dakika", request->data.stop_min},
            {"saniye", request->data.stop_second},
            {"milisaniye", request->data.stop_milisecond},
        };
        data_dict["qrMetni"] = QString::fromStdString(request->data.qr_text);

        qDebug() << "[RosBridgeNode] send_qr_message srv received!";
        qDebug() << "[RosBridgeNode] QR payload:" << QJsonDocument(data_dict).toJson(QJsonDocument::Compact);

        auto promise = std::make_shared<std::promise<bool>>();
        auto future = promise->get_future();

        QMetaObject::invokeMethod(
            ServerManager::instance(),
            [data_dict, promise]() {
                ServerManager::instance()->sendJsonRequestAsync(QNetworkAccessManager::PostOperation,
                                                                "/api/kamikaze_bilgisi", data_dict,
                                                                [promise](bool ok) { promise->set_value(ok); });
            },
            Qt::QueuedConnection);

        bool ok = future.get();

        response->success = ok;
        response->result = ok ? 200 : 400;

        if (ok) {
            qDebug() << "[RosBridgeNode] QR message sent to server successfully";
        } else {
            qDebug() << "[RosBridgeNode] Server rejected lock data";
        }
    } catch (const std::exception& e) {
        qWarning() << "[RosBridgeNode] Error in send_qr_message_callback:" << e.what();
        response->success = false;
        response->result = 400;
    }
}

RosBridgeNode::RosBridgeNode(QObject* parent) : QObject(parent), _impl(std::make_unique<RosImpl>())
{
    qDebug() << "RosBridgeNode: constructor";

#ifdef ROSBRIDGE_ENABLE_ROS
    // Initialize rcl if not already initialized
    if (!rclcpp::ok()) {
        // note: argc/argv not available from QGC; pass empty so rclcpp uses defaults
        rclcpp::init(0, nullptr);
    }

    // make a node owned by this object
    _impl->node = std::make_shared<rclcpp::Node>("RosBridgeNode_qgc");

    _impl->guidanceInfoSub = _impl->node->create_subscription<savasan_general::msg::GuidanceInfo>(
        "guidance/info", rclcpp::QoS(10),
        [this](savasan_general::msg::GuidanceInfo::SharedPtr msg) { this->guidanceInfoCallback(msg); });

    _impl->send_lock_message =
        _impl->node->create_service<savasan_general::srv::SendLock>("send_lock_message", send_lock_message_callback);

    _impl->send_qr_message =
        _impl->node->create_service<savasan_general::srv::SendQR>("send_qr_message", send_qr_message_callback);

    _impl->guidanceCmdPub =
        _impl->node->create_publisher<savasan_general::msg::GuidanceCommand>("guidance/command", rclcpp::QoS(10));

    // Load image topics from settings
    QSettings settings;
    QStringList loadedTopics = settings.value("ImagePanel/Topics", QStringList{"/plane1/image_processed"}).toStringList();
    if (!loadedTopics.isEmpty()) {
        _image_topics = loadedTopics;
    }

    if (!_image_topics.isEmpty()) {
        if (!_image_topics.contains(QString::fromStdString(_impl->selectedImageTopic))) {
            _impl->selectedImageTopic = _image_topics[0].toStdString();
        }
    } else {
        _impl->selectedImageTopic = "";
    }

    // Create subscriptions for all topics
    for (const QString& image_topic : _image_topics) {
        createImageSubscription(image_topic);
    }

    // executor to spin the node in the background
    _impl->executor = std::make_shared<rclcpp::executors::MultiThreadedExecutor>(rclcpp::ExecutorOptions(), 2);
    _impl->executor->add_node(_impl->node);

    // spin in a background thread to service callbacks / futures
    _impl->spinThread = std::thread([this]() {
        // This call blocks until shutdown or executor canceled
        _impl->executor->spin();
    });
#endif
}

RosBridgeNode::~RosBridgeNode()
{
    qDebug() << "RosBridgeNode: destructor";

#ifdef ROSBRIDGE_ENABLE_ROS
    if (_impl->executor) {
        // stop executor and join thread
        _impl->executor->cancel();
    }
    if (_impl->spinThread.joinable()) {
        _impl->spinThread.join();
    }

    // remove node from executor to be tidy
    if (_impl->executor && _impl->node) {
        // safe to remove but executor may already be canceled
        // (guarded)
        try {
            _impl->executor->remove_node(_impl->node);
        } catch (...) { /* ignore */
        }
    }

    // shutdown rcl if needed - be careful if other code uses rclcpp
    if (rclcpp::ok()) {
        rclcpp::shutdown();
    }
#endif
}

int RosBridgeNode::callService(const QString& serviceNameQ)
{
#ifdef ROSBRIDGE_ENABLE_ROS
    const std::string serviceName = serviceNameQ.toStdString();
    const int requestId = _impl->nextRequestId++;

    auto client = getOrCreateClient(_impl->triggerClients, serviceName);

    if (!client->wait_for_service(std::chrono::seconds(1))) {
        QMetaObject::invokeMethod(
            this,
            [this, requestId]() { emit serviceResult(requestId, false, QStringLiteral("service not available")); },
            Qt::QueuedConnection);
        return requestId;
    }

    auto request = std::make_shared<std_srvs::srv::Trigger::Request>();

    client->async_send_request(request, [this, requestId](rclcpp::Client<std_srvs::srv::Trigger>::SharedFuture future) {
        bool success = false;
        QString message;
        try {
            auto response = future.get();
            success = response->success;
            message = QString::fromStdString(response->message);
        } catch (const std::exception& e) {
            message = QString::fromStdString(e.what());
        }
        QMetaObject::invokeMethod(
            this, [this, requestId, success, message]() { emit serviceResult(requestId, success, message); },
            Qt::QueuedConnection);
    });
    return requestId;

#else
    Q_UNUSED(serviceNameQ);
    QMetaObject::invokeMethod(
        this, [this]() { emit serviceResult(-1, false, QStringLiteral("ROS not available in QGC build")); },
        Qt::QueuedConnection);
    return -1;
#endif
}

int RosBridgeNode::setKamikazeParams(double latitude, double longitude, double pullUpAltitude,
                                     double approachHeadingDeg, double diveAngleDeg,
                                     double climbBufferDistance, double reachDistance,
                                     bool setAdvancedParams, double diveStartAltitude,
                                     double pitchPGain, double pitchIGain, double pitchDGain,
                                     double rollPGain, double rollIGain, double rollDGain)
{
#ifdef ROSBRIDGE_ENABLE_ROS
    const int requestId = _impl->nextRequestId++;

    auto client = getOrCreateClient(_impl->setKamikazeParamsClient, "/plane1/guidance/set_kamikaze_params");

    if (!client->wait_for_service(std::chrono::seconds(1))) {
        QMetaObject::invokeMethod(
            this,
            [this, requestId]() { emit serviceResult(requestId, false, QStringLiteral("Service not available")); },
            Qt::QueuedConnection);
        return requestId;
    }

    auto request = std::make_shared<savasan_general::srv::SetKamikazeParams::Request>();
    request->lat = latitude;
    request->lon = longitude;
    request->pull_up_altitude = pullUpAltitude;
    request->approach_heading_deg = approachHeadingDeg;
    request->dive_angle_deg = diveAngleDeg;
    request->climb_buffer_distance = climbBufferDistance;
    request->reach_dist = reachDistance;
    request->set_advanced_params = setAdvancedParams;
    request->dive_start_altitude = diveStartAltitude;
    request->pitch_kp = pitchPGain;
    request->pitch_ki = pitchIGain;
    request->pitch_kd = pitchDGain;
    request->roll_kp = rollPGain;
    request->roll_ki = rollIGain;
    request->roll_kd = rollDGain;

    client->async_send_request(
        request, [this, requestId](rclcpp::Client<savasan_general::srv::SetKamikazeParams>::SharedFuture future) {
            bool success = false;
            QString message;
            try {
                auto response = future.get();
                success = response->success;
                message = QString::fromStdString(response->message);
            } catch (const std::exception& e) {
                message = QString::fromStdString(e.what());
            }
            QMetaObject::invokeMethod(
                this, [this, requestId, success, message]() { emit serviceResult(requestId, success, message); },
                Qt::QueuedConnection);
        });
    return requestId;

#else
    Q_UNUSED(latitude);
    Q_UNUSED(longitude);
    Q_UNUSED(pullUpAltitude);
    Q_UNUSED(approachHeadingDeg);
    Q_UNUSED(diveAngleDeg);
    Q_UNUSED(climbBufferDistance);
    Q_UNUSED(reachDistance);
    Q_UNUSED(setAdvancedParams);
    Q_UNUSED(diveStartAltitude);
    Q_UNUSED(pitchPGain);
    Q_UNUSED(pitchIGain);
    Q_UNUSED(pitchDGain);
    Q_UNUSED(rollPGain);
    Q_UNUSED(rollIGain);
    Q_UNUSED(rollDGain);
    QMetaObject::invokeMethod(
        this, [this]() { emit serviceResult(-1, false, QStringLiteral("ROS not available in QGC build")); },
        Qt::QueuedConnection);
    return -1;
#endif
}

int RosBridgeNode::setKonumHandlingConfig(int target_id, bool fixed_target)
{
#ifdef ROSBRIDGE_ENABLE_ROS
    const int requestId = _impl->nextRequestId++;

    auto client = getOrCreateClient(_impl->konumHandlingConfigClient, "/plane1/konum_handling_config");

    if (!client->wait_for_service(std::chrono::seconds(1))) {
        QMetaObject::invokeMethod(
            this,
            [this, requestId]() { emit serviceResult(requestId, false, QStringLiteral("Service not available")); },
            Qt::QueuedConnection);
        return requestId;
    }

    auto request = std::make_shared<savasan_general::srv::KonumHandlingConfig::Request>();
    request->target_id = target_id;
    request->fixed_target = fixed_target;

    client->async_send_request(
        request, [this, requestId](rclcpp::Client<savasan_general::srv::KonumHandlingConfig>::SharedFuture future) {
            bool success = false;
            try {
                auto response = future.get();
                success = response->success;
            } catch (const std::exception& e) {
                success = false;
                qDebug() << "Error setting konum handling config:" << e.what();
            }
            QMetaObject::invokeMethod(
                this, [this, requestId, success]() { emit serviceResult(requestId, success, QStringLiteral("")); },
                Qt::QueuedConnection);
        });
    return requestId;

#else
    Q_UNUSED(target);
    Q_UNUSED(fixed_target);
    QMetaObject::invokeMethod(
        this, [this]() { emit serviceResult(-1, false, QStringLiteral("ROS not available in QGC build")); },
        Qt::QueuedConnection);
    return -1;
#endif
}

QString RosBridgeNode::selectedImageTopic() const {
    std::lock_guard<std::mutex> lock(_impl->selectedTopicMutex);
    return QString::fromStdString(_impl->selectedImageTopic);
}

void RosBridgeNode::setSelectedImageTopic(const QString& topic){
    bool changed = false;
    {
        std::lock_guard<std::mutex> lock(_impl->selectedTopicMutex);
        if (_impl->selectedImageTopic != topic.toStdString()) {
            _impl->selectedImageTopic = topic.toStdString();
            changed = true;
        }
    }

    if (changed) {
        emit selectedImageTopicChanged();
    }
}

void RosBridgeNode::addImageTopic(const QString& topic)
{
    if (topic.isEmpty()) return;

    if (!_image_topics.contains(topic)) {
        _image_topics.append(topic);

        // Save to settings
        QSettings settings;
        settings.setValue("ImagePanel/Topics", _image_topics);

        emit imageTopicsChanged();

        // Create subscription for the new topic
#ifdef ROSBRIDGE_ENABLE_ROS
        createImageSubscription(topic);
#endif
    }
}

void RosBridgeNode::removeImageTopic(const QString& topic)
{
    if (_image_topics.removeAll(topic) > 0) {
        // Save to settings
        QSettings settings;
        settings.setValue("ImagePanel/Topics", _image_topics);

        // If the removed topic was selected, switch to the first remaining topic
        bool changed = false;
        {
            std::lock_guard<std::mutex> lock(_impl->selectedTopicMutex);
            if (_impl->selectedImageTopic == topic.toStdString()) {
                if (!_image_topics.isEmpty()) {
                    _impl->selectedImageTopic = _image_topics[0].toStdString();
                } else {
                    _impl->selectedImageTopic = "";
                }
                changed = true;
            }
        }

        emit imageTopicsChanged();
        if (changed) {
            emit selectedImageTopicChanged();
        }

        // Remove subscription for the topic
#ifdef ROSBRIDGE_ENABLE_ROS
        removeImageSubscription(topic);
#endif
    }
}

#ifdef ROSBRIDGE_ENABLE_ROS
void RosBridgeNode::createImageSubscription(const QString& image_topic)
{
    std::string topicStr = image_topic.toStdString();

    qDebug() << "Creating subscription for image topic:" << image_topic;

    auto imageSub = _impl->node->create_subscription<sensor_msgs::msg::Image>(
        topicStr, rclcpp::QoS(10),
        [this, image_topic](sensor_msgs::msg::Image::ConstSharedPtr msg) {
            std::string selected;
            {
                std::lock_guard<std::mutex> lock(_impl->selectedTopicMutex);
                selected = _impl->selectedImageTopic;
            }

            if (image_topic.toStdString() != selected) {
                return;
            }
            QImage img = rosImageToQImage(*msg);
            if (img.isNull()) {
                return;
            }

            {
                std::lock_guard<std::mutex> lock(_impl->imageMutex);
                _impl->latestImage = img;
            }

            ++_imageRevision;
            QMetaObject::invokeMethod(this, [this]() { emit imageRevisionChanged(); }, Qt::QueuedConnection);
        });

    // Store in both list and map
    _impl->imageSubs.push_back(imageSub);
    _impl->imageSubsMap[topicStr] = imageSub;
}

void RosBridgeNode::removeImageSubscription(const QString& image_topic)
{
    std::string topicStr = image_topic.toStdString();

    qDebug() << "Removing subscription for image topic:" << image_topic;

    // Remove from map
    auto it = _impl->imageSubsMap.find(topicStr);
    if (it != _impl->imageSubsMap.end()) {
        _impl->imageSubsMap.erase(it);
    }

    // Note: We can't directly remove from the list since we don't have unique identifiers
    // The subscription will be cleaned up when the shared_ptr goes out of scope
    // For now, we just remove it from the map which is sufficient
}
#endif

static QImage rosImageToQImage(const sensor_msgs::msg::Image& msg)
{
    const int w = static_cast<int>(msg.width);
    const int h = static_cast<int>(msg.height);

    if (w <= 0 || h <= 0) {
        return QImage();
    }
    const auto* data = reinterpret_cast<const uchar*>(msg.data.data());
    if (msg.encoding == "rgb8") {
        QImage img(data, w, h, static_cast<int>(msg.step), QImage::Format_RGB888);
        return img.copy();
    }
    if (msg.encoding == "bgr8") {
        QImage img(data, w, h, static_cast<int>(msg.step), QImage::Format_BGR888);
        return img.copy();
    }
    if (msg.encoding == "rgba8") {
        QImage img(data, w, h, static_cast<int>(msg.step), QImage::Format_RGBA8888);
        return img.copy();
    }
    if (msg.encoding == "bgra8") {
        QImage img(data, w, h, static_cast<int>(msg.step), QImage::Format_ARGB32);
        return img.copy();
    }
    if (msg.encoding == "mono8") {
        QImage img(data, w, h, static_cast<int>(msg.step), QImage::Format_Grayscale8);
        return img.copy();
    }
    return QImage();
}

QImage RosBridgeNode::latestImage() const
{
    std::lock_guard<std::mutex> lock(_impl->imageMutex);
    return _impl->latestImage;
}

void RosBridgeNode::publishKonumBilgileri(const QJsonArray& konumArray)
{
    if (!_impl->node || konumArray.isEmpty()) {
        return;
    }

    // Lazily create publisher on first use
    if (!_impl->konumPub) {
        _impl->konumPub =
            _impl->node->create_publisher<savasan_general::msg::KonumBilgileri>("/konum_bilgileri", rclcpp::QoS(10));
    }

    auto msg = std::make_unique<savasan_general::msg::KonumBilgileri>();
    msg->konum_bilgileri.reserve(konumArray.size());

    for (const auto& item : konumArray) {
        if (!item.isObject()) {
            continue;
        }
        QJsonObject obj = item.toObject();

        savasan_general::msg::KonumBilgisi bilgi;
        bilgi.takim_numarasi = obj["takim_numarasi"].toInt(0);
        bilgi.iha_enlem = obj["iha_enlem"].toDouble(0.0);
        bilgi.iha_boylam = obj["iha_boylam"].toDouble(0.0);
        bilgi.iha_irtifa = obj["iha_irtifa"].toDouble(0.0);
        bilgi.iha_dikilme = obj["iha_dikilme"].toDouble(0.0);
        bilgi.iha_yonelme = obj["iha_yonelme"].toDouble(0.0);
        bilgi.iha_yatis = obj["iha_yatis"].toDouble(0.0);
        bilgi.iha_hiz = obj["iha_hizi"].toDouble(0.0);
        bilgi.iha_zamanfarki = obj["zaman_farki"].toInt(0);

        msg->konum_bilgileri.push_back(bilgi);
    }

    _impl->konumPub->publish(*msg);
}

void RosBridgeNode::publishNoFlyZones(const QJsonArray& hssArray)
{
#ifdef ROSBRIDGE_ENABLE_ROS
    if (!_impl->node || hssArray.isEmpty()) {
        return;
    }

    // Lazily create publisher on first use
    if (!_impl->nfzPub) {
        _impl->nfzPub =
            _impl->node->create_publisher<savasan_general::msg::NoFlyZoneArray>("nfz_areas", rclcpp::QoS(10));
    }

    auto nfz_array_msg = std::make_unique<savasan_general::msg::NoFlyZoneArray>();

    for (const auto& item : hssArray) {
        if (!item.isObject()) {
            continue;
        }
        QJsonObject obj = item.toObject();

        savasan_general::msg::NoFlyZone nfz_msg;
        nfz_msg.latitude = obj["hssEnlem"].toDouble(0.0);
        nfz_msg.longitude = obj["hssBoylam"].toDouble(0.0);
        nfz_msg.radius = obj["hssYaricap"].toDouble(0.0);

        nfz_array_msg->zones.push_back(nfz_msg);
    }

    _impl->nfzPub->publish(*nfz_array_msg);
    qDebug() << "Published" << static_cast<int>(nfz_array_msg->zones.size()) << "no-fly zones";

    // Clear existing geofences first
    clearGeofences();

    // Upload new geofences
    for (const auto& zone : nfz_array_msg->zones) {
        uploadGeofence(zone.latitude, zone.longitude, zone.radius);
    }
#endif
}

void RosBridgeNode::clearGeofences()
{
#ifdef ROSBRIDGE_ENABLE_ROS
    if (!_impl->node) {
        return;
    }

    auto client = getOrCreateClient(_impl->commandLongClients, "/plane1/mavros/cmd/command");

    if (!client->wait_for_service(std::chrono::seconds(2))) {
        qWarning() << "MAVROS command service unavailable";
        return;
    }

    auto request = std::make_shared<mavros_msgs::srv::CommandLong::Request>();
    request->command = 402;  // MAV_CMD_NAV_FENCE_CLEAR_ALL
    request->param1 = 0.0;
    request->param2 = 0.0;
    request->param3 = 0.0;
    request->param4 = 0.0;
    request->param5 = 0.0;
    request->param6 = 0.0;
    request->param7 = 0.0;

    client->async_send_request(request, [this](rclcpp::Client<mavros_msgs::srv::CommandLong>::SharedFuture future) {
        try {
            auto response = future.get();
            if (response->success) {
                qInfo() << "Cleared all existing geofences";
            } else {
                qWarning() << "Failed to clear geofences";
            }
        } catch (const std::exception& e) {
            qWarning() << "Error clearing geofences:" << e.what();
        }
    });
#endif
}

void RosBridgeNode::uploadGeofence(double latitude, double longitude, double radius)
{
#ifdef ROSBRIDGE_ENABLE_ROS
    if (!_impl->node) {
        return;
    }

    auto client = getOrCreateClient(_impl->commandLongClients, "/plane1/mavros/cmd/command");

    if (!client->wait_for_service(std::chrono::seconds(2))) {
        qWarning() << "MAVROS command service unavailable";
        return;
    }

    auto request = std::make_shared<mavros_msgs::srv::CommandLong::Request>();
    request->command = 5004;   // NAV_FENCE_CIRCLE_EXCLUSION
    request->param1 = radius;  // No-Fly Zone radius in meters
    request->param2 = 0.0;
    request->param3 = 0.0;
    request->param4 = 0.0;
    request->param5 = latitude;   // Latitude
    request->param6 = longitude;  // Longitude
    request->param7 = 0.0;

    int geofenceId = _impl->nextGeofenceId++;

    client->async_send_request(request, [this, geofenceId, latitude, longitude,
                                         radius](rclcpp::Client<mavros_msgs::srv::CommandLong>::SharedFuture future) {
        try {
            auto response = future.get();
            if (response->success) {
                qInfo() << QString("Geofence %1 uploaded: Lat=%2, Lon=%3, Radius=%4m")
                               .arg(geofenceId)
                               .arg(latitude)
                               .arg(longitude)
                               .arg(radius);
            } else {
                qWarning() << QString("Failed to upload geofence %1").arg(geofenceId);
            }
        } catch (const std::exception& e) {
            qWarning() << QString("Error uploading geofence %1: %2").arg(geofenceId).arg(e.what());
        }
    });
#endif
}

void RosBridgeNode::guidanceInfoCallback(savasan_general::msg::GuidanceInfo::SharedPtr msg)
{
    qDebug() << "GuidanceInfo received";

    // Update current mode
    if (_currentMode != QString::fromStdString(msg->current_mode)) {
        _currentMode = QString::fromStdString(msg->current_mode);
        QMetaObject::invokeMethod(this, [this]() { emit currentModeChanged(); }, Qt::QueuedConnection);
    }

    // Update mode lock
    if (_modeLock != msg->mode_lock) {
        _modeLock = msg->mode_lock;
        QMetaObject::invokeMethod(this, [this]() { emit modeLockChanged(); }, Qt::QueuedConnection);
    }

    // Update method names and auths
    QStringList newMethodNames;
    QList<bool> newMethodAuths;

    for (const auto& name : msg->method_names) {
        newMethodNames.append(QString::fromStdString(name));
    }
    for (bool auth : msg->method_auths) {
        newMethodAuths.append(auth);
    }

    if (_methodNames != newMethodNames) {
        _methodNames = newMethodNames;
        QMetaObject::invokeMethod(this, [this]() { emit methodNamesChanged(); }, Qt::QueuedConnection);
    }

    if (_methodAuths != newMethodAuths) {
        _methodAuths = newMethodAuths;
        QMetaObject::invokeMethod(this, [this]() { emit methodAuthsChanged(); }, Qt::QueuedConnection);
    }
}

void RosBridgeNode::sendGuidanceCommand(int command, bool force)
{
#ifdef ROSBRIDGE_ENABLE_ROS
    if (!_impl->node || !_impl->guidanceCmdPub) {
        return;
    }

    auto msg = std::make_unique<savasan_general::msg::GuidanceCommand>();
    msg->command = static_cast<uint8_t>(command);
    msg->force = force;

    _impl->guidanceCmdPub->publish(*msg);
    qDebug() << "GuidanceCommand sent: command=" << command << ", force=" << force;
#else
    Q_UNUSED(command);
    Q_UNUSED(force);
    qDebug() << "ROS not available - GuidanceCommand not sent";
#endif
}
