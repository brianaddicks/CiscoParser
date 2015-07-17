using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace CiscoParser {
	
    public class Device {
		public List<Interface> Interfaces { get; set; }
		public List<AccessList> AccessLists { get; set; }
    }
}