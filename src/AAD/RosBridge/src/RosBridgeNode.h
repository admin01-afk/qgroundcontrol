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

    Q_INVOKABLE void startYolo();
    Q_INVOKABLE void callService(const QString& serviceName);

signals:
    // emitted on Qt main thread when a service call returns
    void serviceResult(const QString &serviceName, bool success, const QString &message);

private:
    // Use opaque pointers to ROS implementation to avoid MOC template instantiation issues
    class RosImpl;
    std::unique_ptr<RosImpl> _impl;
};
