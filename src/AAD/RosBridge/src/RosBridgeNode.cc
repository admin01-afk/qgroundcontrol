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