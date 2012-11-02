/*
 * Copyright (c) 2011-2012 University of Bremen, TZI
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

#include <pdu.h>
#include <async.h>
#include <resource.h>

generic module CoapEtsiSegmentResourceP(uint8_t uri_key) {
  provides interface CoapResource;
  uses interface Leds;
} implementation {

#define INITIAL_DEFAULT_DATA_SEGMENT "segment"

  unsigned char buf[2];
  coap_pdu_t *response;
  bool lock = FALSE; //TODO: atomic
  coap_async_state_t *temp_async_state = NULL;
  coap_resource_t *temp_resource = NULL;
  unsigned int temp_content_format;

  command error_t CoapResource.initResourceAttributes(coap_resource_t *r) {
#ifdef COAP_CONTENT_TYPE_PLAIN
    coap_add_attr(r, (unsigned char *)"ct", 2, (unsigned char *)"0", 1, 0);
#endif

    if ((r->data = (uint8_t *) coap_malloc(sizeof(INITIAL_DEFAULT_DATA_SEGMENT))) != NULL) {
      memcpy(r->data, INITIAL_DEFAULT_DATA_SEGMENT, sizeof(INITIAL_DEFAULT_DATA_SEGMENT));
      r->data_len = sizeof(INITIAL_DEFAULT_DATA_SEGMENT);
    }

    return SUCCESS;
  }

  /////////////////////
  // GET:
  task void getMethod() {
    response = coap_new_pdu();
    response->hdr->code = COAP_RESPONSE_CODE(205);

    call Leds.led0Toggle();

    coap_add_option(response, COAP_OPTION_CONTENT_TYPE,
		    coap_encode_var_bytes(buf, temp_content_format), buf);

    signal CoapResource.methodDone(SUCCESS,
				   temp_async_state,
				   response,
				   temp_resource);
    lock = FALSE;
  }

  command int CoapResource.getMethod(coap_async_state_t* async_state,
				     uint8_t *val, size_t vallen,
				     struct coap_resource_t *resource,
				     unsigned int content_format) {
    if (lock == FALSE) {
      lock = TRUE;

      temp_async_state = async_state;
      temp_resource = resource;
      temp_content_format = COAP_CONTENT_TYPE_PLAIN;

      post getMethod();
      return COAP_SPLITPHASE;
    } else {
      return COAP_RESPONSE_503;
    }
  }

  /////////////////////
  // PUT:
  command int CoapResource.putMethod(coap_async_state_t* async_state,
				     uint8_t *val, size_t vallen,
				     coap_resource_t *resource,
				     unsigned int content_format) {
    return COAP_RESPONSE_405;
  }

  /////////////////////
  // POST:
  command int CoapResource.postMethod(coap_async_state_t* async_state,
				      uint8_t *val, size_t buflen,
				      struct coap_resource_t *resource,
				      unsigned int content_format) {
    return COAP_RESPONSE_405;
  }

  /////////////////////
  // DELETE:
  command int CoapResource.deleteMethod(coap_async_state_t* async_state,
					uint8_t *val, size_t buflen,
					struct coap_resource_t *resource) {
    return COAP_RESPONSE_405;
  }
}
