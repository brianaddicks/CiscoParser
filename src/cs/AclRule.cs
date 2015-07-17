using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace CiscoParser {
	
    public class AclRule {
		public int Number { get; set; }
		public string Remark { get; set; }
		public string Protocol { get; set; }
		public string Action { get; set; }
		
		public string SourceAddress { get; set; }
		public string SourcePort { get; set; }
		
		public string DestinationAddress { get; set; }
		public string DestinationPort { get; set; }
    }
}