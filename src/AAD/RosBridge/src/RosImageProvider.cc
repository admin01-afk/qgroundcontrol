#include "RosImageProvider.h"
#include <QQmlEngine>
#include "RosBridgeNode.h"

RosImageProvider::RosImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{}

QImage RosImageProvider::requestImage(const QString& id, QSize* size, const QSize& requestedSize)
{
    Q_UNUSED(id);

    QImage img = RosBridgeNode::instance()->latestImage();

    if (size) {
        *size = img.size();
    }

    if (!requestedSize.isEmpty() && !img.isNull()) {
        img = img.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    return img;
}

void registerRosImageProvider(QQmlEngine* engine)
{
    engine->addImageProvider(QStringLiteral("ros"), new RosImageProvider());
}