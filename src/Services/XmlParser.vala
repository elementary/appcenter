/*
* Copyright (c) 2016-2017 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class AppCenter.Services.XmlParser {

    public static Gee.ArrayList<string> node_name_list; 
    public static Gee.ArrayList<string> node_content_list;
    public static Gee.ArrayList<string> element_name_list;
    public static Gee.ArrayList<string> element_content_list;

    private string content; 
 
    private int indent = 0;

    /* For Debug Use
    private void debug_print_xml (string node, string content, char token = '+') {
        string indent = string.nfill (this.indent * 2, ' '); 
        stdout.printf ("%s%c%s: %s\n",indent, token, node, content);
    }
    */

    public string xml_parse_filepath (string path) {

        // Parse the xml document from path
        Xml.Parser.init ();
        stdout.printf(@"[Xml path]: $path\n"); 
        node_name_list = new Gee.ArrayList<string> (); 
        node_content_list = new Gee.ArrayList<string> (); 
        element_name_list = new Gee.ArrayList<string> (); 
        element_content_list = new Gee.ArrayList<string> ();  

        Xml.Doc* doc = Xml.Parser.parse_file (path); 
        if (doc == null) {
            stderr.printf ("File %s not found", path); 
        }

            Xml.Node* root = doc->get_root_element (); 
            if (root == null) {
                delete doc; 
                stderr.printf ("The xml file '%s' is empty", path); 
            } 

            // debug_print_xml ("Root:", root->name);

            parse_node (root);
        
        string xmlstr;
        doc->dump_memory (out xmlstr);  
        return xmlstr;
        //Clean up  
        delete doc;
       
    }

    public string content_data () {
        stdout.printf("data: %s\n",this.content); 
        return this.content; 
    }

    public Gee.ArrayList<string> elements () {
        stdout.printf("list data: %s\n", element_content_list[0]); 
        return element_content_list; 
    }

    private void parse_node (Xml.Node* node) {
        this.indent++; 
            int i = 0; 
            for (Xml.Node* iter = node->children; iter !=null; iter = iter->next) {
                if (iter->type != Xml.ElementType.ELEMENT_NODE) {
                    continue;
                }

                // string node_name = iter->name; 
                // string node_content = iter->get_content ();
               
                // debug_print_xml(node_name,node_content); 

                parse_properties(iter);

                parse_children (iter);
                i++; 
            }

        this.indent--; 
    }

    private void parse_children (Xml.Node* node) {
        this.indent++; 
            int i = 0; 
            for (Xml.Node* iter = node->children; iter !=null; iter = iter->next) {
                if (iter->type != Xml.ElementType.ELEMENT_NODE) {
                    continue;
                }
                string node_name = iter->name; 
                string node_content = iter->get_content ();
                this.content = node_content;

                node_name_list.add(node_name);
                node_content_list.add(@"$node_content");
                
                // debug_print_xml(node_name,node_content); 

                parse_properties(iter);

                parse_node (iter);
                i++; 
            }
        this.indent--; 
    }

    

    private void parse_properties (Xml.Node* node) {
        int i = 0; 
        for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) {
            string attr_name = prop->name; 

            string attr_content = prop->children->content;
            // Provents empty properties 
            if (attr_content != "") {
            element_name_list.add(attr_name);
            element_content_list.add(@"$attr_content");
            }
            // debug_print_xml(attr_name, attr_content, '|');
            i++;

        }
    }

    public Gee.ArrayList<string> get_properties () {
        return node_content_list; 
    }

   


}