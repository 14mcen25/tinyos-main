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

#include <lib6lowpan/lib6lowpan.h>

#include <net.h>

#include <async.h>
#include <resource.h>
#include <uri.h>
#include <debug.h>
#include <pdu.h>
#include <subscribe.h>  // for resource_t
#include <encode.h>
#include <debug.h>
#include <mem.h>

#include "tinyos_coap_resources.h"
#include "blip_printf.h"

#define INDEX "CoAPUdpServer: It works!!"
#define COAP_MEDIATYPE_NOT_SUPPORTED 0xfe

#define GENERATE_PDU(var,t,c,i,copy_token) {				\
	var = coap_new_pdu();						\
	if (var) {							\
	    coap_opt_t *tok;						\
	    var->hdr->type = (t);					\
	    var->hdr->code = (c);					\
	    var->hdr->id = (i);						\
	    tok = coap_check_option(node->pdu, COAP_OPTION_TOKEN);	\
	    if (tok && copy_token)					\
		coap_add_option(					\
		pdu, COAP_OPTION_TOKEN, COAP_OPT_LENGTH(*tok), COAP_OPT_VALUE(*tok)); \
	}								\
    }

module CoapUdpServerP {
    provides interface CoAPServer;
    uses interface LibCoAP as LibCoapServer;
    uses interface Leds;
    uses interface CoapResource[uint8_t uri];
} implementation {
    coap_context_t *ctx_server;
    coap_resource_t *r;
    //get index (int) from uri_key (char[4])
    //defined in tinyos_coap_resources.h
    uint8_t get_index_for_key(coap_key_t uri_key) {
	uint8_t i = 0;
	for (; i < COAP_LAST_RESOURCE; i++) {
	    if (memcmp(uri_index_map[i].uri_key, uri_key, sizeof(coap_key_t)) == 0)
		return uri_index_map[i].index;
	}
	return COAP_NO_SUCH_RESOURCE;
    }

    void hnd_coap_async_tinyos(coap_context_t  *ctx,
			       struct coap_resource_t *resource,
			       coap_address_t *peer,
			       coap_pdu_t *request,
			       str *token,
			       coap_pdu_t *response);

    int coap_save_splitphase(coap_context_t *ctx, coap_queue_t *node);

    command error_t CoAPServer.setupContext(uint16_t port) {
	coap_address_t listen_addr;

	coap_address_init(&listen_addr);
	listen_addr.addr.sin6_port = port;
	//TODO: address needed?

	ctx_server = coap_new_context(&listen_addr);

	if (!ctx_server) {
	    coap_log(LOG_CRIT, "cannot create CoAP context\r\n");
	    return FAIL;
	}

	return call LibCoapServer.setupContext(port);
    }

    ///////////////////
    // register resources
    command error_t CoAPServer.registerResources() {
      int i;
      unsigned int supported_methods;

      if (ctx_server == NULL)
	return FAIL;

      for (i=0; i < COAP_LAST_RESOURCE; i++) {
	// set the hash for the URI
	coap_hash_path(uri_index_map[i].uri,
		       uri_index_map[i].uri_len - 1,
		       uri_index_map[i].uri_key);

	r = coap_resource_init((unsigned char *)uri_index_map[i].uri, uri_index_map[i].uri_len-1, 0);
	supported_methods = uri_index_map[i].supported_methods;

	r->data = NULL;

	if (r == NULL)
	  return FAIL;

	if ((supported_methods & GET_SUPPORTED) == GET_SUPPORTED)
	  coap_register_handler(r, COAP_REQUEST_GET, hnd_coap_async_tinyos);
	if ((supported_methods & POST_SUPPORTED) == POST_SUPPORTED)
	  coap_register_handler(r, COAP_REQUEST_POST, hnd_coap_async_tinyos);
	if ((supported_methods & PUT_SUPPORTED) == PUT_SUPPORTED)
	  coap_register_handler(r, COAP_REQUEST_PUT, hnd_coap_async_tinyos);
	if ((supported_methods & DELETE_SUPPORTED) == DELETE_SUPPORTED)
	  coap_register_handler(r, COAP_REQUEST_DELETE, hnd_coap_async_tinyos);

#ifndef WITHOUT_OBSERVE
	r->observable = uri_index_map[i].observable;
#endif
	call CoapResource.initResourceAttributes[i](r);

	coap_add_resource(ctx_server, r);
      }
      return SUCCESS;
    }

    event void LibCoapServer.read(struct sockaddr_in6 *from, void *data,
				  uint16_t len, struct ip6_metadata *meta) {

	printf("CoapUdpServer: LibCoapServer.read()\n");
	/*call Leds.led0On();
	  call Leds.led1On();
	  call Leds.led2On();*/

	// CHECK: lock access to context?
	// copy data into ctx_server
	ctx_server->bytes_read = len;
	memcpy(ctx_server->buf, data, len);
	// copy src into context
	memcpy(&ctx_server->src.addr, from, sizeof (struct sockaddr_in6));

	coap_read(ctx_server);
	coap_dispatch(ctx_server);
    }

    ///////////////////
    // all TinyOS CoAP requests have to go through this
    void hnd_coap_async_tinyos(coap_context_t  *ctx,
			       struct coap_resource_t *resource,
			       coap_address_t *peer,
			       coap_pdu_t *request,
			       str *token,
			       coap_pdu_t *response) {

	coap_opt_iterator_t opt_iter;
	int rc;
	size_t size;
	unsigned char *data;
	coap_async_state_t *tmp;
	coap_async_state_t *async_state = NULL;

	unsigned int media_type = COAP_MEDIATYPE_NOT_SUPPORTED;
	coap_attr_t *attr = NULL;
	coap_option_iterator_init(request, &opt_iter, COAP_OPT_ALL);

	/* set media_type if available */
	if ((coap_check_option(request, COAP_OPTION_ACCEPT, &opt_iter) && request->hdr->code == COAP_REQUEST_GET) ||
	    (coap_check_option(request, COAP_OPTION_CONTENT_TYPE, &opt_iter) && (request->hdr->code & (COAP_REQUEST_PUT & COAP_REQUEST_POST)))) {
	  do {
	    while ((attr = coap_find_attr(resource, attr, (unsigned char*)"ct", 2))){
	      if (atoi((const char *)attr->value.s) == coap_decode_var_bytes(COAP_OPT_VALUE(opt_iter.option),
									     COAP_OPT_LENGTH(opt_iter.option))) {
		media_type = coap_decode_var_bytes(COAP_OPT_VALUE(opt_iter.option),
						     COAP_OPT_LENGTH(opt_iter.option));
		break;
	      }
	    }
	  } while (coap_option_next(&opt_iter) && (attr == NULL));
	} else {
	  media_type = COAP_MEDIATYPE_ANY;
	}

	if (media_type == COAP_MEDIATYPE_NOT_SUPPORTED) {
	  response->hdr->code = (request->hdr->code == COAP_REQUEST_GET
				 ? COAP_RESPONSE_CODE(406)
				 : COAP_RESPONSE_CODE(415));
	  goto cleanup;
	}

#ifndef WITHOUT_OBSERVE
	//handler has been called by check_notify()
	if (request == NULL){

	  //TODO: check options
	  coap_add_option(response, COAP_OPTION_SUBSCRIPTION, 0, NULL);

	  if (resource->data_len != 0) {
	    coap_add_data(response, resource->data_len, resource->data);
	    response->hdr->code = COAP_RESPONSE_CODE(205);
	  } else
	    response->hdr->code = COAP_RESPONSE_CODE(500);

	  return;
	} else {
	  if (coap_check_option(request, COAP_OPTION_SUBSCRIPTION, &opt_iter)){

	    coap_add_observer(resource, peer, token);
	    async_state = coap_register_async(ctx, peer, request,
					  COAP_ASYNC_OBSERVED,
					  (void *)NULL);
	  } else {
	    //remove client from observer list, if already registered
	    if (coap_find_observer(resource, peer, token)) {
	      coap_delete_observer(resource, peer, token);
	    }
#endif
	    async_state = coap_register_async(ctx, peer, request,
					  COAP_ASYNC_CONFIRM,
					  (void *)NULL);
#ifndef WITHOUT_OBSERVE
	  }
	}
#endif
	/*
	  call Leds.led0On();
	  call Leds.led1On();
	  call Leds.led2On();

	*/

	/* response->hdr->code = COAP_RESPONSE_CODE(205); */
	/* coap_add_option(response, COAP_OPTION_CONTENT_TYPE, */
	/*                 coap_encode_var_bytes(buf, COAP_MEDIATYPE_TEXT_PLAIN), buf); */

	/* if (token->length) */
	/*   coap_add_option(response, COAP_OPTION_TOKEN, token->length, token->s); */

	/* response->length += snprintf((char *)response->data, */
	/* 				 response->max_size - response->length, */
	/* 				 "%u", 42); */

	coap_get_data(request, &size, &data);

	if (request->hdr->code == COAP_REQUEST_GET)
	    rc = call CoapResource.getMethod[get_index_for_key(resource->key)](async_state,
									       data,
									       size,
									       media_type);
	else if (request->hdr->code == COAP_REQUEST_POST)
	    rc = call CoapResource.postMethod[get_index_for_key(resource->key)](async_state,
										data,
										size,
										resource,
										media_type);
	else if (request->hdr->code == COAP_REQUEST_PUT)
	    rc = call CoapResource.putMethod[get_index_for_key(resource->key)](async_state,
									       data,
									       size,
									       resource,
									       media_type);
	else if (request->hdr->code == COAP_REQUEST_DELETE)
	    rc = call CoapResource.deleteMethod[get_index_for_key(resource->key)](async_state,
										  data,
										  size);
	else
	  rc = COAP_RESPONSE_CODE(405);

	if (rc == FAIL) {
	    /* default handler returns FAIL -> Resource not available -> Response: 404 */
	    response->hdr->code = COAP_RESPONSE_CODE(404);

	    //TODO: set hdr->type?

	    if (token->length)
		coap_add_option(response, COAP_OPTION_TOKEN, token->length, token->s);

	} else if (request->hdr->type == COAP_MESSAGE_NON) {
	    /* don't reply with ACK to NON's. Set response type to
	       COAP_MESSAGE_NON, so that net.c is not sending it.  */
	    response->hdr->type = COAP_MESSAGE_NON;
	    response->hdr->code = 0x0;
	} else if (rc == COAP_SPLITPHASE) {
	    /* TinyOS is split-phase, only in error case an immediate response
	       is set. Otherwise set type to COAP_MESSAGE_NON, so that net.c
	       is not sending it. */
	    response->hdr->type = COAP_MESSAGE_NON;
	    return;
	} else {
	    response->hdr->code = rc;
	    //CHECK: set hdr->type?

	    if (token->length)
		coap_add_option(response, COAP_OPTION_TOKEN, token->length, token->s);
	}

	//we don't have split-phase -> do some cleanup
	cleanup:
	coap_remove_async(ctx, async_state->id, &tmp);
	coap_free_async(async_state);
	async_state = NULL;
    }

    default command error_t CoapResource.initResourceAttributes[uint8_t uri_key](coap_resource_t *resource) {
	    return FAIL;
 }

 default command int CoapResource.getMethod[uint8_t uri_key](coap_async_state_t* async_state,
							     uint8_t* val, size_t vallen,
							     unsigned int media_type) {
     //printf("** coap: default (get not available for this resource)....... %i\n", uri_key);
     return FAIL;
 }
 default command int CoapResource.putMethod[uint8_t uri_key](coap_async_state_t* async_state,
							     uint8_t* val, size_t vallen, coap_resource_t *resource,
							     unsigned int media_type) {
     //printf("** coap: default (put not available for this resource)....... %i\n", uri_key);
     return FAIL;
 }
 default command int CoapResource.postMethod[uint8_t uri_key](coap_async_state_t* async_state,
							      uint8_t* val, size_t vallen, coap_resource_t *resource,
							      unsigned int media_type) {
     //printf("** coap: default (post not available for this resource)....... %i\n", uri_key);
     return FAIL;
 }
 default command int CoapResource.deleteMethod[uint8_t uri_key](coap_async_state_t* async_state,
								uint8_t* val, size_t vallen) {
     //printf("** coap: default (delete not available for this resource)....... %i\n", uri_key);
     return FAIL;
 }

 event void CoapResource.methodDone[uint8_t uri_key](error_t result,
						     uint8_t responsecode,
						     coap_async_state_t* async_state,
						     uint8_t* val,
						     size_t vallen,
						     uint8_t media_type,
						     coap_resource_t *resource) {
     unsigned char buf[2];
     coap_pdu_t *response;
     coap_async_state_t *tmp;

     response = coap_new_pdu();

     if (!response) {
// 	 debug("check_async: insufficient memory, we'll try later\n");
	 //TODO: handle error...
	 return;
     }

     response->hdr->type = COAP_MESSAGE_ACK;
     response->hdr->code = responsecode;
     response->hdr->id = async_state->message_id;

     if (media_type != COAP_MEDIATYPE_ANY)
	 coap_add_option(response, COAP_OPTION_CONTENT_TYPE,
			 coap_encode_var_bytes(buf, media_type), buf);

     if (async_state->tokenlen)
	 coap_add_option(response, COAP_OPTION_TOKEN, async_state->tokenlen, async_state->token);

#ifndef WITHOUT_OBSERVE
       if (async_state->flags & COAP_ASYNC_OBSERVED){
	coap_add_option(response, COAP_OPTION_SUBSCRIPTION, 0, NULL);
      }
#endif

     if (vallen != 0)
	 coap_add_data(response, vallen, val);

     if (coap_send(ctx_server, &async_state->peer, response) == COAP_INVALID_TID) {
	 debug("check_async: cannot send response for message %d\n",
	       response->hdr->id);
     }
     coap_delete_pdu(response);
     coap_remove_async(ctx_server, async_state->id, &tmp);
     coap_free_async(async_state);
     async_state = NULL;

#ifndef WITHOUT_OBSERVE
     //resource dirty -> notify subscribers
     if (resource->dirty == 1)
       coap_check_notify(ctx_server);
#endif
     if (resource->data)
       coap_free(resource->data);
 }

 event void CoapResource.methodNotDone[uint8_t uri_key](coap_async_state_t* async_state,
							uint8_t responsecode) {
     coap_pdu_t *response;
     size_t size = sizeof(coap_hdr_t) + 8;
     //size += async_state->tokenlen; //CHECK: include token in preACK?

     // for NON request, no ACK
     if (async_state->flags & COAP_ASYNC_CONFIRM) {
	 response = coap_pdu_init(COAP_MESSAGE_ACK,
				  responsecode, 0, size);

	 if (!response) {
	     debug("check_async: insufficient memory, we'll try later\n");
	     //TODO: handle error...
	     return;
	 }

	 response->hdr->id = async_state->message_id;

	 if (coap_send(ctx_server, &async_state->peer, response) == COAP_INVALID_TID) {
	     debug("check_async: cannot send response for message %d\n",
		   response->hdr->id);
	     coap_delete_pdu(response);
	 }
     }
 }

 event void CoapResource.methodDoneSeparate[uint8_t uri_key](error_t result,
							     uint8_t responsecode,
							     coap_async_state_t* async_state,
							     uint8_t* val, size_t vallen,
							     uint8_t mediatype) {
     unsigned char buf[2];
     coap_pdu_t *response;
     coap_async_state_t *tmp;

     size_t size = sizeof(coap_hdr_t) + 8;
     size += async_state->tokenlen;

     response = coap_pdu_init(async_state->flags & COAP_ASYNC_CONFIRM
			      ? COAP_MESSAGE_CON
			      : COAP_MESSAGE_NON,
			      responsecode, 0, size);
     if (!response) {
	 debug("check_async: insufficient memory, we'll try later\n");
	 //TODO: handle error...
     }

     response->hdr->id = coap_new_message_id(ctx_server); // SEPARATE requires new message id

     if (mediatype != COAP_MEDIATYPE_ANY)
	 coap_add_option(response, COAP_OPTION_CONTENT_TYPE,
			 coap_encode_var_bytes(buf, mediatype), buf);

     if (async_state->tokenlen)
	 coap_add_option(response, COAP_OPTION_TOKEN, async_state->tokenlen, async_state->token);

     if (vallen != 0)
	 coap_add_data(response, vallen, val);

     if (coap_send(ctx_server, &async_state->peer, response) == COAP_INVALID_TID) {
	 debug("check_async: cannot send response for message %d\n",
	       response->hdr->id);
	 coap_delete_pdu(response);
     }

     coap_remove_async(ctx_server, async_state->id, &tmp);
     coap_free_async(async_state);
     async_state = NULL;

     //thp:TODO: observe??
 }
}
