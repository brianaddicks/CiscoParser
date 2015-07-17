using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace CiscoParser {
	
    public class ChannelGroup {
		public int GroupNumber  { get; set; }
		public string Mode  { get; set; }
    }
}