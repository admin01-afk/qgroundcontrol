#include "RosBridgeNode.h"

#include <QDebug>
#include <QCoreApplication>
#include <QMetaObject>
#include <thread>
#include <mutex>
#include <unordered_map>

#ifdef ROSBRIDGE_ENABLE_ROS
#include "rclcpp/rclcpp.hpp"
#include "std_srvs/srv/trigger.hpp"
#include <QtGui/QImage>
#include "sensor_msgs/msg/image.hpp"
#include "savasan_general/msg/konum_bilgileri.hpp"
#include "savasan_general/msg/konum_bilgisi.hpp"
#include "savasan_general/msg/guidance_command.hpp"
#include "savasan_general/msg/guidance_info.hpp"
#include <QJsonArray>
#include <QJsonObject>
#endif

// Only include ROS headers if available and enabled (for colcon/QGC build with ROS)
#ifdef ROSBRIDGE_ENABLE_ROS
class RosBridgeNode::RosImpl
{
public:
    std::shared_ptr<rclcpp::Node> node;
    std::shared_ptr<rclcpp::executors::SingleThreadedExecutor> executor;
    std::thread spinThread;

    std::mutex clientMutex;
    std::unordered_map<std::string, std::shared_ptr<TriggerClient>> triggerClients;

    std::mutex imageMutex;
    std::shared_ptr<rclcpp::Subscription<sensor_msgs::msg::Image>> imageSub;
    QImage latestImage;

    // Guidance
    rclcpp::Subscription<savasan_general::msg::GuidanceInfo>::SharedPtr guidanceInfoSub;
    rclcpp::Publisher<savasan_general::msg::GuidanceCommand>::SharedPtr guidanceCmdPub;

    std::shared_ptr<rclcpp::Publisher<savasan_general::msg::KonumBilgileri>> konumPub;

    std::atomic<int> nextRequestId{1};
};
#else
class RosBridgeNode::RosImpl
{
public:
};
#endif
#ifdef ROSBRIDGE_ENABLE_ROS
std::shared_ptr<RosBridgeNode::TriggerClient>
RosBridgeNode::getOrCreateTriggerClient(const std::string& serviceName)
{
    std::lock_guard<std::mutex> lock(_impl->clientMutex);

    auto it = _impl->triggerClients.find(serviceName);
    if (it != _impl->triggerClients.end()) {
        return it->second;
    }

    auto client = _impl->node->create_client<std_srvs::srv::Trigger>(serviceName);
    _impl->triggerClients.emplace(serviceName, client);
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

RosBridgeNode::RosBridgeNode(QObject* parent)
    : QObject(parent), _impl(std::make_unique<RosImpl>())
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
        "guidance/info",
        rclcpp::QoS(10),
        [this](savasan_general::msg::GuidanceInfo::SharedPtr msg) {
            this->guidanceInfoCallback(msg);
        }
    );

    _impl->guidanceCmdPub = _impl->node->create_publisher<savasan_general::msg::GuidanceCommand>(
        "guidance/command", rclcpp::QoS(10));

    // executor to spin the node in the background
    _impl->executor = std::make_shared<rclcpp::executors::SingleThreadedExecutor>();
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
        } catch (...) { /* ignore */ }
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

    auto client = getOrCreateTriggerClient(serviceName);

    if (!client->wait_for_service(std::chrono::seconds(1))) {
        QMetaObject::invokeMethod(this, [this, requestId]() {
            emit serviceResult(requestId, false, QStringLiteral("service not available"));
        }, Qt::QueuedConnection);
        return requestId;
    }

    auto request = std::make_shared<std_srvs::srv::Trigger::Request>();

    client->async_send_request(
        request,
        [this, requestId](rclcpp::Client<std_srvs::srv::Trigger>::SharedFuture future) {
            bool success = false;
            QString message;
            try {
                auto response = future.get();
                success = response->success;
                message = QString::fromStdString(response->message);
            } catch (const std::exception& e) {
                message = QString::fromStdString(e.what());
            }
            QMetaObject::invokeMethod(this, [this, requestId, success, message]() {
                emit serviceResult(requestId, success, message);
            }, Qt::QueuedConnection);
        }
    );
    return requestId;

#else
    Q_UNUSED(serviceNameQ);
    QMetaObject::invokeMethod(this, [this]() {
        emit serviceResult(-1, false, QStringLiteral("ROS not available in QGC build"));
    }, Qt::QueuedConnection);
    return -1;
#endif
}


#ifdef ROSBRIDGE_ENABLE_ROS
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

void RosBridgeNode::subscribeImageTopic(const QString& topicName)
{
    if (!_impl->node || _impl->imageSub) {
        return;
    }

    const std::string topic = topicName.toStdString();

    _impl->imageSub = _impl->node->create_subscription<sensor_msgs::msg::Image>(
        topic,
        rclcpp::QoS(10),
        [this](sensor_msgs::msg::Image::ConstSharedPtr msg) {
            QImage img = rosImageToQImage(*msg);
            if (img.isNull()) {
                return;
            }

            {
                std::lock_guard<std::mutex> lock(_impl->imageMutex);
                _impl->latestImage = img;
            }

            ++_imageRevision;
            QMetaObject::invokeMethod(this, [this]() {
                emit imageRevisionChanged();
            }, Qt::QueuedConnection);
        });
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
        _impl->konumPub = _impl->node->create_publisher<savasan_general::msg::KonumBilgileri>(
            "/konum_bilgileri",
            rclcpp::QoS(10)
        );
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

void RosBridgeNode::guidanceInfoCallback(savasan_general::msg::GuidanceInfo::SharedPtr msg){
    qDebug() << "GuidanceInfo received";

    // Update current mode
    if (_currentMode != QString::fromStdString(msg->current_mode)) {
        _currentMode = QString::fromStdString(msg->current_mode);
        QMetaObject::invokeMethod(this, [this]() {
            emit currentModeChanged();
        }, Qt::QueuedConnection);
    }

    // Update mode lock
    if (_modeLock != msg->mode_lock) {
        _modeLock = msg->mode_lock;
        QMetaObject::invokeMethod(this, [this]() {
            emit modeLockChanged();
        }, Qt::QueuedConnection);
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
        QMetaObject::invokeMethod(this, [this]() {
            emit methodNamesChanged();
        }, Qt::QueuedConnection);
    }

    if (_methodAuths != newMethodAuths) {
        _methodAuths = newMethodAuths;
        QMetaObject::invokeMethod(this, [this]() {
            emit methodAuthsChanged();
        }, Qt::QueuedConnection);
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

#endif
