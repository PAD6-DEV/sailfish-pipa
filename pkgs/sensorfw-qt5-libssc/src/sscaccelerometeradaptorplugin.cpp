/****************************************************************************
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#include "sscaccelerometeradaptorplugin.h"
#include "sscaccelerometeradaptor.h"
#include "sensormanager.h"

#include <QDebug>

void SscAccelerometerAdaptorPlugin::Register(class Loader &)
{
    qInfo() << "registering sscaccelerometeradaptor";
    SensorManager &sm = SensorManager::instance();
    sm.registerDeviceAdaptor<SscAccelerometerAdaptor>("accelerometeradaptor");
}
