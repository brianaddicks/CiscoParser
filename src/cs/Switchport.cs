using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace CiscoParser {
	
    public class Switchport {
		public bool Enabled { get; set; }
		public SwitchportAccess Access { get; set; }
		public SwitchportTrunk Trunk { get; set; }
		
		public Switchport () {
			this.Access = new SwitchportAccess {};
			this.Trunk = new SwitchportTrunk {};
		}
    }
	
	
}