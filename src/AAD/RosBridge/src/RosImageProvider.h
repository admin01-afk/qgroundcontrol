#pragma once

#include <QQuickImageProvider>
#include <QImage>
#include <QSize>

class QQmlEngine;

/*
qml:
    source: "image://ros/plane1/camera/image_processed"

The format is image://provider/id, where:

ros is the provider (registered in RosImageProvider.cc)
plane1/camera/image_processed is the topic name passed as the id parameter
*/

class RosImageProvider : public QQuickImageProvider
{
public:
    RosImageProvider();
    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;
};

void registerRosImageProvider(QQmlEngine* engine);