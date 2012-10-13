/*
 * Copyright (c) 2011 University of Bremen, TZI
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "StorageVolumes.h"
#include <lib6lowpan/6lowpan.h>
#include "tinyos_coap_resources.h"

configuration CoapBlipC {

} implementation {
  components MainC;
  components LedsC;
  components CoapBlipP;
  components LibCoapAdapterC;
  components IPStackC;

  CoapBlipP.Boot -> MainC;
  CoapBlipP.Leds -> LedsC;
  CoapBlipP.RadioControl ->  IPStackC;

#ifdef RPL_ROUTING
  components RPLRoutingC;
#endif

#ifdef COAP_SERVER_ENABLED
  components CoapUdpServerC;
  components new UdpSocketC() as UdpServerSocket;
  CoapBlipP.CoAPServer -> CoapUdpServerC;
  CoapUdpServerC.LibCoapServer -> LibCoapAdapterC.LibCoapServer;
  LibCoapAdapterC.UDPServer -> UdpServerSocket;

#if defined (COAP_CONTENT_TYPE_JSON) || defined (COAP_CONTENT_TYPE_XML)
  components LocalIeeeEui64C;
#endif

#if defined (COAP_RESOURCE_TEMP)  || defined (COAP_RESOURCE_HUM) || defined (COAP_RESOURCE_ALL)
  components new SensirionSht11C() as HumTempSensor;
#endif

#ifdef COAP_RESOURCE_TEMP
  components new CoapReadResourceC(uint16_t, INDEX_TEMP) as CoapReadTempResource;
  components new CoapBufferTempTranslateC() as CoapBufferTempTranslate;
  CoapReadTempResource.Read -> CoapBufferTempTranslate.ReadTemp;
  CoapBufferTempTranslate.Read -> HumTempSensor.Temperature;
  CoapUdpServerC.CoapResource[INDEX_TEMP] -> CoapReadTempResource.CoapResource;
#if defined (COAP_CONTENT_TYPE_JSON) || defined (COAP_CONTENT_TYPE_XML)
  CoapReadTempResource.LocalIeeeEui64 -> LocalIeeeEui64C;
#endif
#endif

#ifdef COAP_RESOURCE_HUM
  components new CoapReadResourceC(uint16_t, INDEX_HUM) as CoapReadHumResource;
  components new CoapBufferHumTranslateC() as CoapBufferHumTranslate;
  CoapReadHumResource.Read -> CoapBufferHumTranslate.ReadHum;
  CoapBufferHumTranslate.Read -> HumTempSensor.Humidity;
  CoapUdpServerC.CoapResource[INDEX_HUM] -> CoapReadHumResource.CoapResource;
#if defined (COAP_CONTENT_TYPE_JSON) || defined (COAP_CONTENT_TYPE_XML)
  CoapReadHumResource.LocalIeeeEui64 -> LocalIeeeEui64C;
#endif
#endif

#if defined (COAP_RESOURCE_VOLT)  || defined (COAP_RESOURCE_ALL)
  components new VoltageC() as VoltSensor;
#endif

#ifdef COAP_RESOURCE_VOLT
  components new CoapReadResourceC(uint16_t, INDEX_VOLT) as CoapReadVoltResource;
  components new CoapBufferVoltTranslateC() as CoapBufferVoltTranslate;
  CoapReadVoltResource.Read -> CoapBufferVoltTranslate.ReadVolt;
  CoapBufferVoltTranslate.Read -> VoltSensor.Read;
  CoapUdpServerC.CoapResource[INDEX_VOLT] -> CoapReadVoltResource.CoapResource;
#if defined (COAP_CONTENT_TYPE_JSON) || defined (COAP_CONTENT_TYPE_XML)
  CoapReadVoltResource.LocalIeeeEui64 -> LocalIeeeEui64C;
#endif
#endif

#ifdef COAP_RESOURCE_ALL
  components new CoapReadResourceC(val_all_t, INDEX_ALL) as CoapReadAllResource;
  components new SensirionSht11C() as HumTempSensorAll;
  components CoapResourceCollectorC;
  CoapReadAllResource.Read -> CoapResourceCollectorC.ReadAll;
  components new CoapBufferTempTranslateC() as CoapBufferTempTranslateAll;
  CoapResourceCollectorC.ReadTemp -> CoapBufferTempTranslateAll.ReadTemp;
  CoapBufferTempTranslateAll.Read -> HumTempSensorAll.Temperature;
  components new CoapBufferHumTranslateC() as CoapBufferHumTranslateAll;
  CoapResourceCollectorC.ReadHum -> CoapBufferHumTranslateAll.ReadHum;
  CoapBufferHumTranslateAll.Read -> HumTempSensorAll.Humidity;
  components new CoapBufferVoltTranslateC() as CoapBufferVoltTranslateAll;
  CoapResourceCollectorC.ReadVolt -> CoapBufferVoltTranslateAll.ReadVolt;
  CoapBufferVoltTranslateAll.Read -> VoltSensor.Read;
  CoapUdpServerC.CoapResource[INDEX_ALL] -> CoapReadAllResource.CoapResource;
#endif

#ifdef COAP_RESOURCE_KEY
  components new CoapFlashResourceC(INDEX_KEY) as CoapFlashResource;
  components new ConfigStorageC(VOLUME_CONFIGKEY);
  CoapFlashResource.ConfigStorage -> ConfigStorageC.ConfigStorage;
  CoapBlipP.Mount  -> ConfigStorageC.Mount;
  CoapUdpServerC.CoapResource[INDEX_KEY]  -> CoapFlashResource.CoapResource;
#endif

#ifdef COAP_RESOURCE_LED
  components new CoapLedResourceC(INDEX_LED) as CoapLedResource;
  CoapLedResource.Leds -> LedsC;
  CoapUdpServerC.CoapResource[INDEX_LED]  -> CoapLedResource.CoapResource;
#endif

#ifdef COAP_RESOURCE_ROUTE
  components new CoapRouteResourceC(uint16_t, INDEX_ROUTE) as CoapReadRouteResource;
  CoapReadRouteResource.ForwardingTable -> IPStackC;
  CoapUdpServerC.CoapResource[INDEX_ROUTE] -> CoapReadRouteResource.CoapResource;
#endif

#ifdef COAP_RESOURCE_ETSI_IOT_TEST
  components new CoapEtsiTestResourceC(INDEX_ETSI_TEST);
  CoapUdpServerC.CoapResource[INDEX_ETSI_TEST] -> CoapEtsiTestResourceC.CoapResource;
#endif

#ifdef COAP_RESOURCE_ETSI_IOT_SEPARATE
  components new CoapEtsiSeparateResourceC(INDEX_ETSI_SEPARATE);
  CoapUdpServerC.CoapResource[INDEX_ETSI_SEPARATE] -> CoapEtsiSeparateResourceC.CoapResource;
#endif

#ifdef COAP_RESOURCE_ETSI_IOT_SEGMENT
  components new CoapEtsiSegmentResourceC(INDEX_ETSI_SEGMENT);
  CoapUdpServerC.CoapResource[INDEX_ETSI_SEGMENT] -> CoapEtsiSegmentResourceC.CoapResource;
#endif


#endif

#ifdef COAP_CLIENT_ENABLED
  components CoapUdpClientC;
  components new UdpSocketC() as UdpClientSocket;
  CoapBlipP.CoAPClient -> CoapUdpClientC;
  CoapUdpClientC.LibCoapClient -> LibCoapAdapterC.LibCoapClient;
  LibCoapAdapterC.UDPClient -> UdpClientSocket;
  CoapBlipP.ForwardingTableEvents -> IPStackC.ForwardingTableEvents;
#endif

#ifdef PRINTFUART_ENABLED
  /* This component wires printf directly to the serial port, and does
   * not use any framing.  You can view the output simply by tailing
   * the serial device.  Unlike the old printfUART, this allows us to
   * use PlatformSerialC to provide the serial driver.
   *
   * For instance:
   * $ stty -F /dev/ttyUSB0 115200
   * $ tail -f /dev/ttyUSB0
  */
  components SerialPrintfC;

  /* This is the alternative printf implementation which puts the
   * output in framed tinyos serial messages.  This lets you operate
   * alongside other users of the tinyos serial stack.
   */
  // components PrintfC;
  // components SerialStartC;
#endif
  }
