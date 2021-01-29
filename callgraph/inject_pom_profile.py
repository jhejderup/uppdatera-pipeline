import sys, os, re
from lxml import etree

plugins_txt = '<profiles><profile><id>uppdatera</id><properties><maven.test.skip>false</maven.test.skip></properties><build><plugins><plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-surefire-plugin</artifactId><configuration><argLine>${agent.uppdatera}</argLine></configuration></plugin></plugins></build></profile></profiles>'
plugin_txt = '<profile><id>uppdatera</id><properties><maven.test.skip>false</maven.test.skip></properties><build><plugins><plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-surefire-plugin</artifactId><configuration><argLine>${agent.uppdatera}</argLine></configuration></plugin></plugins></build></profile>'
plugins  = etree.fromstring(plugins_txt)
plugin = etree.fromstring(plugin_txt)

try:
 
 ns= {"d" : "http://maven.apache.org/POM/4.0.0"}
 root = etree.parse(sys.argv[1] + '/pom.xml')
 exists = root.xpath('boolean(/d:project/d:profiles)',namespaces=ns)
 exists_no_ns = root.xpath('boolean(/project/profiles)')

 if exists and not exists_no_ns:
  xml_plugins = root.xpath('/d:project/d:profiles',namespaces=ns)
  xml_plugins[0].append(plugin)
  root.write('pom.xml', pretty_print=True)
 elif exists_no_ns and not exists:
  xml_plugins = root.xpath('/project/profiles')
  xml_plugins[0].append(plugin)
  root.write('pom.xml', pretty_print=True)
 else:
  xml_plugins = root.xpath('/d:project',namespaces=ns)
  xml_non = root.xpath('/project')
  if len(xml_plugins) > 0:
   xml_plugins[0].append(plugins)
   root.write(sys.argv[1] +'/pom.xml', pretty_print=True)
  else:
   xml_non[0].append(plugins)
   root.write(sys.argv[1] +'/pom.xml', pretty_print=True)
except:
 sys.exit(1)

 sys.exit(0)