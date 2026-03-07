#include "rclcpp/rclcpp.hpp"
#include "std_srvs/srv/trigger.hpp"
#include <memory>
#include <chrono>
#include <string>

using namespace std::chrono_literals;

/* RosBridgeNode
    bridge between QGC buttons and ROS service calls...
    gonna replace savasan_gui (savasan_2025/savasan_gui/savasan_gui/gui.py)

    at the moment it just calls /start_yolo
    tested and it works with savasan_2025
*/
class RosBridgeNode : public rclcpp::Node
{
public:
    RosBridgeNode() : Node("RosBridgeNode")
    {
        RCLCPP_INFO(this->get_logger(), "RosBridgeNode starting...");

        // call start_yolo
        call_service("/start_yolo");
    }

private:
    void call_service(const std::string& service_name){
        rclcpp::Client<std_srvs::srv::Trigger>::SharedPtr client;
        client = this->create_client<std_srvs::srv::Trigger>(service_name);
        while (!client->wait_for_service(1s)) {
            RCLCPP_WARN(this->get_logger(), ("Waiting for " + service_name + "...").c_str());
        }
        auto request = std::make_shared<std_srvs::srv::Trigger::Request>();
        auto result_future = client->async_send_request(request,
                [this, service_name](rclcpp::Client<std_srvs::srv::Trigger>::SharedFuture future){
                    auto response = future.get();
                    if (response->success)
                        RCLCPP_INFO(this->get_logger(), (service_name + " succeeded: " + response->message).c_str());
                    else
                        RCLCPP_WARN(this->get_logger(), (service_name + " failed: " + response->message).c_str());
                }
            );
    }
};

int main(int argc, char **argv)
{
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<RosBridgeNode>());
    rclcpp::shutdown();
    return 0;
}
