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

#ifndef _COAP_TINYOS_COAP_RESOURCES_H_
#define _COAP_TINYOS_COAP_RESOURCES_H_

#include <pdu.h>

#define SENSOR_VALUE_INVALID 0xFFFE
#define SENSOR_NOT_AVAILABLE 0xFFFF

//user defined resources

enum {
#if defined (COAP_RESOURCE_TEMP) || defined (COAP_RESOURCE_ALL)
    INDEX_TEMP,
#endif
#if defined (COAP_RESOURCE_HUM) || defined (COAP_RESOURCE_ALL)
    INDEX_HUM,
#endif
#if defined (COAP_RESOURCE_VOLT) || defined (COAP_RESOURCE_ALL)
    INDEX_VOLT,
#endif
#ifdef COAP_RESOURCE_ALL
    INDEX_ALL,
#endif
#ifdef COAP_RESOURCE_KEY
    INDEX_KEY,
#endif
#ifdef COAP_RESOURCE_LED
    INDEX_LED,
#endif
#ifdef COAP_RESOURCE_ROUTE
    INDEX_ROUTE,
#endif
#ifdef COAP_RESOURCE_ETSI_IOT_TEST
    INDEX_ETSI_TEST,
#endif
#ifdef COAP_RESOURCE_ETSI_IOT_SEPARATE
    INDEX_ETSI_SEPARATE,
#endif
    COAP_NO_SUCH_RESOURCE = 0xff
};

typedef nx_struct val_all
{
  nx_uint8_t id_t:4;
  nx_uint8_t length_t:4;
  nx_uint16_t temp;
  nx_uint8_t id_h:4;
  nx_uint8_t length_h:4;
  nx_uint16_t hum;
  nx_uint8_t id_v:4;
  nx_uint8_t length_v:4;
  nx_uint16_t volt;
} val_all_t;

#ifdef COAP_RESOURCE_KEY
typedef nx_struct config_t
{
  nx_uint8_t version;
  nx_uint8_t EUI64[8];
  nx_uint8_t KEY128[16];
} config_t;
#endif

#define MAX_CONTENT_TYPE_LENGTH 2

#define GET_SUPPORTED 1
#define POST_SUPPORTED 2
#define PUT_SUPPORTED 4
#define DELETE_SUPPORTED 8

//uri properties for index<->uri_key conversion
typedef struct index_uri_key
{
  uint8_t index;
  const unsigned char uri[MAX_URI_LENGTH];
  uint8_t uri_len;
  coap_key_t uri_key;
  const unsigned char contenttype[MAX_CONTENT_TYPE_LENGTH];
  uint8_t contenttype_len;
  uint8_t supported_methods:4;
} index_uri_key_t;

index_uri_key_t uri_index_map[NUM_URIS] = {
#if defined (COAP_RESOURCE_TEMP) || defined (COAP_RESOURCE_ALL)
  {
      INDEX_TEMP,
      "st", sizeof("st"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      GET_SUPPORTED
  },
#endif
#if defined (COAP_RESOURCE_HUM) || defined (COAP_RESOURCE_ALL)
  {
      INDEX_HUM,
      "sh", sizeof("sh"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      GET_SUPPORTED
  },
#endif
#if defined (COAP_RESOURCE_VOLT) || defined (COAP_RESOURCE_ALL)
  {
      INDEX_VOLT,
      "sv", sizeof("sv"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      GET_SUPPORTED
  },
#endif
#ifdef COAP_RESOURCE_ALL
  {
      INDEX_ALL,
      "r", sizeof("r"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      GET_SUPPORTED
  },
#endif
#ifdef COAP_RESOURCE_KEY
  {
      INDEX_KEY,
      "ck", sizeof("ck"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      (GET_SUPPORTED | PUT_SUPPORTED)
  },
#endif
#ifdef COAP_RESOURCE_LED
  {
      INDEX_LED,
      "l", sizeof("l"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      (GET_SUPPORTED | PUT_SUPPORTED)
  },
#endif
#ifdef COAP_RESOURCE_ROUTE
  {
      INDEX_ROUTE,
      "rt", sizeof("rt"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      GET_SUPPORTED
  },
#endif

#ifdef COAP_RESOURCE_ETSI_IOT_TEST
  {
      INDEX_ETSI_TEST,
      "test", sizeof("test"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      (GET_SUPPORTED | PUT_SUPPORTED)
  },
#endif
#ifdef COAP_RESOURCE_ETSI_IOT_SEPARATE
  {
      INDEX_ETSI_SEPARATE,
      "separate", sizeof("separate"),
      {0,0,0,0}, // uri_key will be set later
      "42", sizeof("42"), // application/octet-stream
      (GET_SUPPORTED | PUT_SUPPORTED)
  },
#endif

};

#endif
