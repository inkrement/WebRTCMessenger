library unittest.messenger;

import 'package:unittest/unittest.dart';
import 'package:WebRTCMessenger/WebRTCMessenger/webrtcmessenger.dart';

main() {
  
  group('messenger', () {
  
    /**
     * create new messenger
     */
    test('create messenger', (){
      Messenger msg = new Messenger();
    });
    
    test('test singleton', (){
      Messenger msg1 = new Messenger();
      Messenger msg2 = new Messenger();
      
      expect(msg1.hashCode, msg2.hashCode);
    });
    
    
    
  });
}