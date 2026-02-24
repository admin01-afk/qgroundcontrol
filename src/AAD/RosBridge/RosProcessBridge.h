#pragma once

#include <QObject>

class RosProcessBridge : public QObject
{
    Q_OBJECT
public:
    explicit RosProcessBridge(QObject* parent = nullptr);
};
