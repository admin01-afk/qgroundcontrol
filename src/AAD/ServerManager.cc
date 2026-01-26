#include "ServerManager.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrl>
#include <QDebug>
#include <functional>
#include <QApplicationStatic>
#include <QDir>

Q_APPLICATION_STATIC(ServerManager, _serverManager)

ServerManager* ServerManager::instance()
{
    return _serverManager();
}

ServerManager::ServerManager(QObject* parent)
    : QObject(parent)
{
    _nam = new QNetworkAccessManager(this);
    connect(qApp, &QCoreApplication::aboutToQuit,this, &ServerManager::stopServerSim); // prevent stray servers sim processes
}

/* helpers */

QJsonObject ServerManager::qvariantmapToJson(const QVariantMap& m) const
{
    QJsonObject obj;
    for (auto it = m.constBegin(); it != m.constEnd(); ++it) {
        const QVariant& v = it.value();
        switch (v.typeId()) {
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
        if (reply->error() != QNetworkReply::NoError) {
            qDebug() << "ERROR:" << reply->error();
            emit loginFailed(reply->errorString());
            reply->deleteLater();
            return;
        }

        processReplyJson(reply, [this](const QJsonObject& obj){
            if (obj.contains("takim_numarasi")) {
                int team = obj.value("takim_numarasi").toInt();
                emit loginSucceeded(team);
                qDebug() << "loged in";
            } else {
                QString err = obj.contains("error") ? obj.value("error").toString() : "Unknown login error";
                emit loginFailed(err);
                qDebug() << "ERROR:LOGIN FAILED";
            }
        });
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

void ServerManager::checkConnection()
{
    QNetworkRequest req{ QUrl(_baseUrl) };
    req.setAttribute(QNetworkRequest::RedirectionTargetAttribute, true);

    QNetworkReply* reply = _nam->head(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        // Network-level failure ONLY
        if (reply->error() == QNetworkReply::HostNotFoundError ||
            reply->error() == QNetworkReply::ConnectionRefusedError ||
            reply->error() == QNetworkReply::TimeoutError) {

            emit connectionResult(false);
        } else {
            // ANY HTTP response (200, 404, 500, etc.)
            emit connectionResult(true);
        }

        reply->deleteLater();
    });
}

void ServerManager::startServerSim()
{
    if (_serversimProcess) {qWarning() << "Server sim already running";return;}

    _serversimProcess = new QProcess(this);
    _serversimProcess->setProcessChannelMode(QProcess::MergedChannels);

    connect(_serversimProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        if (!_serversimProcess) return;

        const QByteArray data = _serversimProcess->readAllStandardOutput();
        const QString text = QString::fromUtf8(data);

        for (const QString& line : text.split('\n', Qt::SkipEmptyParts)) {
            emit serverLog(line);
        }
    });

    connect(_serversimProcess,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int code, QProcess::ExitStatus status) {
                qWarning() << "Server sim exited:" << code << status;
                emit serverError("Server sim exited:" + code + status);
                _serversimProcess->deleteLater();
                _serversimProcess = nullptr;
                emit serversimRunningChanged();   // ✅ state changed
            });

    const QString server_sim_script =
        QDir::homePath() + "/qgroundcontrol/src/AAD/server_sim/server.py";
    _serversimProcess->start("python3", { server_sim_script });


    emit serversimRunningChanged();   // ✅ state changed
}

void ServerManager::stopServerSim()
{
    if (_serversimProcess) {
        _serversimProcess->terminate();
    }
}


bool ServerManager::serversimRunning() const
{
    return _serversimProcess != nullptr &&
           _serversimProcess->state() != QProcess::NotRunning;
}
