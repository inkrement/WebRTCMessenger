/**
 * WebRtcDataChannel
 * 
 * @author Christian Hotz-Behofsits <chris.hotz.behofsits@gmail.com>
 */

part of messenger.connections;

class WebRtcDataChannel extends Connection{
  //map of ice providers
  Map iceServers = {'iceServers':[{'url':'stun:stun.l.google.com:19302'}]};
  
  //peer connection constraints (currently unused)
  var pcConstraint = {};
  
  //RTCDataChannel options
  Map _dcOptions = {};
  
  static final _log = new Logger("messenger.connections.WebRtcDataChannel");
  
  //JavaScript Proxy of RTCPeerConnection
  RtcPeerConnection _rpc;
  
  //JavaScript Proxy of RTCDataChannel
  RtcDataChannel _dc;
  
  /**
   * constructor
   */

  WebRtcDataChannel(SignalingChannel sc):super(sc), _dc=null{
    
    /* create RTCPeerConnection */
    _rpc = new RtcPeerConnection(iceServers);
    
    /*
     * listen for incoming RTCDataChannels
     */
    
    _rpc.onDataChannel.listen((RtcDataChannelEvent event){
      _log.fine("incoming RtcDataChannel invitation received");
      
      //set RTCDataChannel
      _dc = event.channel;
      
      /*
       * set RTCDataChannel callbacks
       */
      
      //onMessage
      _dc.onMessage.listen((MessageEvent event){
        _log.fine("Message received from RtCDataChannel");
        
        _newMessageController.add(new NewMessageEvent(MessengerMessage.deserialize(event.data)));
      });
      
      //onOpen
      _dc.onOpen.listen((_){
        _setCommunicationState(new ConnectionState.fromRTCDataChannelState(_dc.readyState));
        _listen_completer.complete(sc.id);
      });
      
      //onClose
      _dc.onClose.listen((_){
        _setCommunicationState(
            new ConnectionState.fromRTCDataChannelState(_dc.readyState)
            );
      });
      
      _dc.onError.listen((x){
        _log.shout("RtcDatachannel error occured: " + x.toString());
        _setCommunicationState(ConnectionState.ERROR);
        this.close();
      });
      
      //set state to current DC_State
      _setCommunicationState(new ConnectionState.fromRTCDataChannelState(_dc.readyState));
      
    });
  }
  
  /**
   * gotSignalingMessage callback
   */
  gotSignalingMessage(NewMessageEvent mevent){
    
    switch(mevent.getMessage().getMessageType()){
      case MessageType.ICE_CANDIDATE:
        _log.fine("new ICE Candidate received");
        
        //deserialize
        RtcIceCandidate iceCandidate = new RtcIceCandidate(JSON.decode(mevent.getMessage().getContent()));
        
        //add candidate
        _rpc.addIceCandidate(iceCandidate,
            ()=>_log.info("ice candidate added"), 
            (error)=>_log.warning(error.toString()));
        break;
      
      /** create answer **/
      case MessageType.WEBRTC_OFFER:
        _log.fine("new SDP offer received");
        
        final Map sdp_map = JSON.decode(mevent.getMessage().getContent());

        //deserialize
        RtcSessionDescription sdp = new RtcSessionDescription(sdp_map);
        
        _rpc.setRemoteDescription(sdp).then((_){
          createAnswer();
        }).catchError((e){
          _log.shout("Not able to set remote SDP(-offer) description: " + e.toString());
          _setCommunicationState(ConnectionState.ERROR);
          this.close();
        });
        
        break;
        
      /** finish **/
      case MessageType.WEBRTC_ANSWER:
        _log.fine("new SDP answer received");
        
        final Map sdp_map = JSON.decode(mevent.getMessage().getContent());

        //deserialize
        RtcSessionDescription sdp = new RtcSessionDescription(sdp_map);
        
        _rpc.setRemoteDescription(sdp).then((_){
            createAnswer();
          }).catchError((e){
          _log.shout("not able to set remote sdp(-answer) description" + e.toString());
          _setCommunicationState(ConnectionState.ERROR);
          this.close();
        });
        
        break;
        
      default:
        _log.shout("new undefined signaling channel message received: " + mevent.getMessage().toString());
        _setCommunicationState(ConnectionState.ERROR);
        this.close();
    }
  }
  
  /**
   * createAnswer
   * 
   * creates new SDP Answer and sends it over signalingChannel
   */
  createAnswer(){
    _rpc.createAnswer().then((RtcSessionDescription sdp_answer){
      _log.fine("create new SDP answer");
      
      _rpc.setLocalDescription(sdp_answer);
      
      //serialize sdp answer
      final String jsonString = JSON.encode({
        'sdp':sdp_answer.sdp,
        'type':sdp_answer.type
      });
      
      //send ice candidate to other peer
      _sc.send(new MessengerMessage(jsonString, MessageType.WEBRTC_ANSWER));
      
    }).catchError((e){
      _log.shout("not able create SDP answer: " + e.toString());
      _setCommunicationState(ConnectionState.ERROR);
      this.close();
    });
  }
  
  /**
   * listen
   * 
   * listen for incoming RTCPeerConnections
   * 
   * @return Future
   */
  Future<int> listen(){
    _log.info("start listening");
    
    //process all incoming signaling messages
    _sc.onReceive.listen(gotSignalingMessage);
    
    /*
     * New IceCandidate Callback
     */
    _rpc.onIceCandidate.listen((RtcIceCandidateEvent event) {
      _log.fine("new ice candidate received");
      
      if(event.candidate != null){
        RtcIceCandidate ic = event.candidate;
        
        try{
          //serialize ice candidate
          final String serializedIceCandidate = JSON.encode(
              {
                'candidate': ic.candidate, 
                'sdpMLineIndex': ic.sdpMLineIndex,
                'sdpMid':ic.sdpMid
                }
              );
          
          //send ice candidate to other peer
          _sc.send(new MessengerMessage(serializedIceCandidate, MessageType.ICE_CANDIDATE));
          
          _log.fine("new ice candidate serialized and sent to other peer");
        } catch(e){
          _log.shout("not able to send ice candidate to other peer" + e.toString());
        }
      }
    });
    
    return _listen_completer.future;
  }
  
  /**
   * connect
   * 
   * establish RTCPeerConnection and create RTCDataChannel
   * 
   * @return Future
   */
  Future<int> connect(){
    _log.info("connect to other peer");
    
    //listen for incoming connection
    listen();
    
    /*
     * create new RTCDataChannel
     */
    
    try {
      _dc = _rpc.createDataChannel("sendDataChannel", _dcOptions);
      _log.fine('created new rtcdatachannel');
      
      /*
       * RTCDataChannel callbacks
       */
      
      //onOpen
      _dc.onOpen.listen((_){
        _setCommunicationState(new ConnectionState.fromRTCDataChannelState(_dc.readyState));
        _connection_completer.complete(_sc.id);
      });
      
      //onClose
      _dc.onClose.listen((_){
        _log.info("datachannel closed!");
        
        _setCommunicationState(new ConnectionState.fromRTCDataChannelState(_dc.readyState));
      });
      
      //onMessage
      
      _dc.onMessage.listen((MessageEvent event){
        _log.fine("Message received from DataChannel");
        
        _newMessageController.add(new NewMessageEvent(MessengerMessage.deserialize(event.data)));
      });
      
      /*
       * create SDP OFFER of RTCPeerConnection
       */
      _rpc.createOffer().then(( sdp_offer){
        _log.fine("create sdp offer");
        
        _rpc.setLocalDescription(sdp_offer);
        
        final Map sdp_map = {"sdp":sdp_offer.sdp, "type":sdp_offer.type};
        final String sdp_string = JSON.encode(sdp_map);
        
        _log.finest("serialized SDP message: " + sdp_string);
        
        //send serialized string to other peer
        _sc.send(new MessengerMessage(sdp_string, MessageType.WEBRTC_OFFER));
        
      });

    } catch (e) {
      _connection_completer.completeError("could not complete connect: ${e}", e.stackTrace);
      _setCommunicationState(ConnectionState.ERROR);
      this.close();
    }
    
    return _connection_completer.future;
  }
  
  /**
   * init send worker
   * 
   * sends all buffered messages
   */
  _init_send_worker(){
    
    //serialize
    if(_dc == null)
      throw new StateError("could not send message. No DataChannel exists!");
 
    if(this.readyState != ConnectionState.CONNECTED)
      throw new StateError("could not send message. DataChannel is not open!");
    
    _sendController.stream.listen((MessengerMessage msg){
      _log.finer("send message to : ${_sc.id.toString()}");
      
      _dc.send(MessengerMessage.serialize(msg));
    });
    
  }

  /**
   * shutdown RTCPeerConnection and RTCDataChannel
   * 
   * RTCPeerConnection should close the RTCDataChannel automatically
   * but it's done explicit for clearer structure.
   */
  close(){
    if(_dc != null) _dc.close();
    if(_rpc != null) _rpc.close();
  }
 
  
}