#include "RosBridgeNode.h"

#include <QDebug>
#include <QCoreApplication>
#include <QMetaObject>
#include <thread>

// Only include ROS headers if available and enabled (for colcon/QGC build with ROS)
#ifdef ROSBRIDGE_ENABLE_ROS
    #include "rclcpp/rclcpp.hpp"
    #include "std_srvs/srv/trigger.hpp"

    // Implementation class that holds all ROS-specific types
    class RosBridgeNode::RosImpl
    {
    public:
        std::shared_ptr<rclcpp::Node> node;
        std::shared_ptr<rclcpp::executors::SingleThreadedExecutor> executor;
        std::thread spinThread;
    };
#else
    // Stub implementation for QGC CMake build (without ROS headers)
    class RosBridgeNode::RosImpl
    {
    public:
        // Empty stub
    };
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

// have service_names here, not in qml
void RosBridgeNode::startYolo() { callService("/start_yolo"); }

void RosBridgeNode::callService(const QString& serviceNameQ)
{
#ifdef ROSBRIDGE_ENABLE_ROS
    const std::string serviceName = serviceNameQ.toStdString();

    // do the waiting + call in another std::thread so we don't block the UI thread
    std::thread([this, serviceName]() {
        // create client on this node (safe to create from any thread)
        auto client = _impl->node->create_client<std_srvs::srv::Trigger>(serviceName);

        // wait for service with timeout loops (so thread is responsive)
        using namespace std::chrono_literals;
        rclcpp::WallRate wait_rate(1s);
        int attempts = 0;
        while (!client->wait_for_service(1s)) {
            attempts++;
            if (attempts % 5 == 0) {
                qDebug() << "RosBridgeNode: still waiting for service" << QString::fromStdString(serviceName);
            }
            // if rclcpp was shutdown, abort
            if (!rclcpp::ok()) {
                QMetaObject::invokeMethod(this, [this, serviceName]() {
                    emit serviceResult(QString::fromStdString(serviceName), false, QStringLiteral("rclcpp shutdown"));
                }, Qt::QueuedConnection);
                return;
            }
        }

        auto request = std::make_shared<std_srvs::srv::Trigger::Request>();

        // use async_send_request with callback
        auto send_goal_future = client->async_send_request(
            request,
            [this, serviceName](rclcpp::Client<std_srvs::srv::Trigger>::SharedFuture future) {
                try {
                    auto response = future.get();
                    const bool success = response->success;
                    const QString message = QString::fromStdString(response->message);
                    // emit on Qt main thread (queued)
                    QMetaObject::invokeMethod(this, [this, serviceName, success, message]() {
                        emit serviceResult(QString::fromStdString(serviceName), success, message);
                    }, Qt::QueuedConnection);
                } catch (const std::exception &e) {
                    QMetaObject::invokeMethod(this, [this, serviceName]() {
                        emit serviceResult(QString::fromStdString(serviceName), false,
                                           QStringLiteral("service future exception"));
                    }, Qt::QueuedConnection);
                }
            }
        );

        // don't block here — callback will emit the signal
    }).detach();
#else
    // Stub: emit result immediately when ROS not available
    qDebug() << "RosBridgeNode: ROS not available, service call stubbed:" << serviceNameQ;
    QMetaObject::invokeMethod(this, [this, serviceNameQ]() {
        emit serviceResult(serviceNameQ, false, QStringLiteral("ROS not available in QGC build"));
    }, Qt::QueuedConnection);
#endif
}
