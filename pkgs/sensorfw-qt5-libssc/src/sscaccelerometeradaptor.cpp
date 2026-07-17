/****************************************************************************
**
** sensorfw-qt5-libssc — Qualcomm SSC accelerometer adaptor for Sailfish
** Copyright (C) 2026 PAD6-DEV
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#include "sscaccelerometeradaptor.h"

#include "config.h"
#include "datatypes/utils.h"
#include "logging.h"

#include <libssc.h>

#include <glib.h>
#include <gio/gio.h>

#include <QCoreApplication>
#include <QDebug>

/* m/s² → milli-G (same factor as hybrisaccelerometeradaptor) */
#ifndef GRAVITY_RECIPROCAL_THOUSANDS
#define GRAVITY_RECIPROCAL_THOUSANDS 101.971621298
#endif

void sscAccelMeasurementTrampoline(SSCSensorAccelerometer *sensor,
                                   float x, float y, float z,
                                   void *userData)
{
    Q_UNUSED(sensor);
    auto *self = static_cast<SscAccelerometerAdaptor *>(userData);
    if (self)
        self->handleMeasurement(x, y, z);
}

SscAccelerometerAdaptor::SscAccelerometerAdaptor(const QString &id)
    : DeviceAdaptor(id)
    , buffer_(new DeviceAdaptorRingBuffer<AccelerationData>(32))
    , sensor_(nullptr)
    , measurementHandlerId_(0)
    , glibTimer_(nullptr)
    , sensorOpen_(false)
{
    setAdaptedSensor("accelerometer", "Qualcomm SSC accelerometer (libssc)", buffer_);
    setDescription("libssc / Snapdragon Sensor Core accelerometer");
    introduceAvailableInterval(DataRange(10 * 1000, 1000 * 1000, 0));
}

SscAccelerometerAdaptor::~SscAccelerometerAdaptor()
{
    stopAdaptor();
    delete buffer_;
}

void SscAccelerometerAdaptor::init()
{
}

bool SscAccelerometerAdaptor::startAdaptor()
{
    if (!glibTimer_) {
        glibTimer_ = new QTimer(this);
        connect(glibTimer_, &QTimer::timeout, this, &SscAccelerometerAdaptor::pumpGlib);
        glibTimer_->setInterval(10);
    }
    if (!glibTimer_->isActive())
        glibTimer_->start();
    return true;
}

void SscAccelerometerAdaptor::stopAdaptor()
{
    stopSensor();
    if (glibTimer_)
        glibTimer_->stop();
}

bool SscAccelerometerAdaptor::startSensor()
{
    if (sensorOpen_)
        return true;

    if (!startAdaptor())
        return false;

    GError *error = nullptr;
    sensor_ = ssc_sensor_accelerometer_new_sync(nullptr, &error);
    if (!sensor_) {
        qCWarning(lcSensorFw) << id() << "ssc_sensor_accelerometer_new_sync failed:"
                              << (error ? error->message : "unknown");
        if (error)
            g_error_free(error);
        return false;
    }

    measurementHandlerId_ = g_signal_connect(sensor_, "measurement",
                                             G_CALLBACK(sscAccelMeasurementTrampoline),
                                             this);

    if (!ssc_sensor_accelerometer_open_sync(sensor_, nullptr, &error)) {
        qCWarning(lcSensorFw) << id() << "ssc_sensor_accelerometer_open_sync failed:"
                              << (error ? error->message : "unknown");
        if (error)
            g_error_free(error);
        if (measurementHandlerId_) {
            g_signal_handler_disconnect(sensor_, measurementHandlerId_);
            measurementHandlerId_ = 0;
        }
        g_object_unref(sensor_);
        sensor_ = nullptr;
        return false;
    }

    sensorOpen_ = true;
    qCInfo(lcSensorFw) << id() << "SSC accelerometer started";
    return true;
}

void SscAccelerometerAdaptor::stopSensor()
{
    if (!sensor_)
        return;

    if (sensorOpen_) {
        GError *error = nullptr;
        ssc_sensor_accelerometer_close_sync(sensor_, nullptr, &error);
        if (error) {
            qCWarning(lcSensorFw) << id() << "ssc close:" << error->message;
            g_error_free(error);
        }
        sensorOpen_ = false;
    }

    if (measurementHandlerId_) {
        g_signal_handler_disconnect(sensor_, measurementHandlerId_);
        measurementHandlerId_ = 0;
    }
    g_object_unref(sensor_);
    sensor_ = nullptr;
    qCInfo(lcSensorFw) << id() << "SSC accelerometer stopped";
}

void SscAccelerometerAdaptor::pumpGlib()
{
    GMainContext *ctx = g_main_context_default();
    while (g_main_context_pending(ctx))
        g_main_context_iteration(ctx, FALSE);
}

void SscAccelerometerAdaptor::handleMeasurement(float x, float y, float z)
{
    AccelerationData *d = buffer_->nextSlot();
    d->timestamp_ = Utils::getTimeStamp();
    d->x_ = x * GRAVITY_RECIPROCAL_THOUSANDS;
    d->y_ = y * GRAVITY_RECIPROCAL_THOUSANDS;
    d->z_ = z * GRAVITY_RECIPROCAL_THOUSANDS;
    buffer_->commit();
    buffer_->wakeUpReaders();
}
