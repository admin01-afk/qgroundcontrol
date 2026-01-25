#include "ServerManager.h"
#include "QGCApplication.h"
#include <QApplicationStatic>
#include "QGCApplication.h"
#include <QDebug>
#include <mavlink.h>


#include <QApplicationStatic>
Q_APPLICATION_STATIC(ServerManager, _serverManager)

ServerManager* ServerManager::instance()
{
    _nam = new QNetworkAccessManager(this);
    return _serverManager();
}
/*
ServerManager::ServerManager(QObject* parent)
    : QObject(parent)
{
    _nam = new QNetworkAccessManager(this);
    // Optionally connect NAM signals for global logging:
    connect(_nam, &QNetworkAccessManager::finished, this, [](QNetworkReply* r){ qDebug() << "NAM finished:" << r->url(); });
}
*/
/* API methods */
void ServerManager::login(const QString& username, const QString& password)
{
    QUrl url(_baseUrl + "/api/giris");
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QVariantMap body;
    body["kadi"] = username;
    body["sifre"] = password;
    QJsonObject json = qvariantmapToJson(body);
    QByteArray payload = QJsonDocument(json).toJson();

    QNetworkReply* reply = _nam->post(req, payload);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        QByteArray data = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            emit loginFailed(reply->errorString());
            reply->deleteLater();
            return;
        }
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isObject()) {
            emit loginFailed("Invalid JSON");
            reply->deleteLater();
            return;
        }
        QJsonObject obj = doc.object();
        // depending on your server JSON field name:
        if (obj.contains("takim_numarasi")) {
            int team = obj.value("takim_numarasi").toInt();
            emit loginSucceeded(team);
        } else {
            QString err = obj.contains("error") ? obj.value("error").toString() : "Unknown login error";
            emit loginFailed(err);
        }
        reply->deleteLater();
    });
}

void ServerManager::getQRCoordinates()
{
    QUrl url(_baseUrl + "/api/qr_koordinati");
    QNetworkRequest req(url);
    QNetworkReply* reply = _nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        processReplyJson(reply, [this](const QJsonObject& obj){
            if (obj.contains("qrEnlem") && obj.contains("qrBoylam")) {
                double lat = obj.value("qrEnlem").toDouble();
                double lon = obj.value("qrBoylam").toDouble();
                emit qrCoordinatesReceived(QGeoCoordinate(lat, lon));
            } else {
                emit errorOccurred("Invalid QR coordinate response");
            }
        });
    });
}

void ServerManager::processReplyJson(QNetworkReply* reply, std::function<void(const QJsonObject&)> onSuccess)
{
    QByteArray data = reply->readAll();
    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (reply->error() != QNetworkReply::NoError) {
        QString err = QString("Network error: %1 (HTTP %2) - %3")
                .arg(reply->errorString()).arg(httpStatus).arg(QString::fromUtf8(data));
        emit errorOccurred(err);
        reply->deleteLater();
        return;
    }

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        emit errorOccurred(QString("JSON parse error: %1").arg(parseError.errorString()));
        reply->deleteLater();
        return;
    }

    if (!doc.isObject()) {
        emit errorOccurred(QString("Unexpected JSON reply: %1").arg(QString::fromUtf8(data)));
        reply->deleteLater();
        return;
    }

    QJsonObject obj = doc.object();
    if (onSuccess) onSuccess(obj);
    reply->deleteLater();
}

QJsonObject ServerManager::qvariantmapToJson(const QVariantMap& m) const
{
    QJsonObject obj;
    for (auto it = m.constBegin(); it != m.constEnd(); ++it) {
        const QVariant& v = it.value();
        switch (v.userType()) {
        case QMetaType::Bool:
            obj.insert(it.key(), v.toBool());
            break;
        case QMetaType::Int:
        case QMetaType::LongLong:
            obj.insert(it.key(), QJsonValue::fromVariant(v.toLongLong()));
            break;
        case QMetaType::Double:
            obj.insert(it.key(), v.toDouble());
            break;
        default:
            obj.insert(it.key(), QJsonValue(v.toString()));
            break;
        }
    }
    return obj;
}
