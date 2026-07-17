/****************************************************************************
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#include "sscalsadaptorplugin.h"
#include "sscalsadaptor.h"
#include "sensormanager.h"

#include <QDebug>

void SscAlsAdaptorPlugin::Register(class Loader &)
{
    qInfo() << "registering sscalsadaptor";
    SensorManager &sm = SensorManager::instance();
    sm.registerDeviceAdaptor<SscAlsAdaptor>("alsadaptor");
}
