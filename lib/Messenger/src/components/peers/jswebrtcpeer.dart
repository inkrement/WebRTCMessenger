part of messenger;

class JsWebRtcPeer extends Peer{
  
  /**
   * constructor
   */
  JsWebRtcPeer([String name="", Level logLevel=Level.FINE]):super(name, logLevel){  
    
  }
  
  Stream<NewConnectionEvent> listen(SignalingChannel sc){
    JsWebRtcConnection c = new JsWebRtcConnection(sc);
    Future<int> f = c.listen();
    
    //add to list of connections. index is identity of other peer
    //TODO: test if identity is unique
    f.then((int id){
      _connections[id] = c;
      log.info("new connection added! (now: ${connections.length.toString()})");
      newConnectionController.add(new NewConnectionEvent(c));
      
      //redirect messages
      c.newMessageController.stream.listen((NewMessageEvent e){
        
        log.info("message redirected");
        newMessageController.add(e);
      });
    });
    
    return newConnectionController.stream;
  }
  
  Stream<NewConnectionEvent> connect(SignalingChannel sc){
    JsWebRtcConnection c = new JsWebRtcConnection(sc);
    Future<int> f = c.connect();
    
    f.then((int id) {
      _connections[id] = c;
      log.info("new connection added! (now: ${connections.length.toString()})");
      newConnectionController.add(new NewConnectionEvent(c));
      
      //redirect messages
      c.newMessageController.stream.listen((NewMessageEvent e){
        
        log.info("message redirected");
        newMessageController.add(e);
      });
    });
    
    return newConnectionController.stream;
  }
 
  
  /**
   * disconnect Peer
   */
  disconnect(JsWebRtcPeer o){
    //TODO: abort rtc connection
    //close Datachannel
    
    _connections.remove(o);
  }
  
  
  
  /**
   * close Connection
   * 
   * TODO: implementation
   */
  close(){
    //_connections.forEach((Peer p, Connection c)=>disconnect(p));
  }
  
  
  
  /**
   * send Message
   * 
   * @ TODO: check if datachannel open. else throw exception
   */
  send(int id, Message msg){
    if(!_connections.containsKey(id))
      throw new StateError("list of connections does not contain peer ${name}");
    
    _connections[id].send(msg);
  }
  
}