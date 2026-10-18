/*********************************************************************************************
*                                        MIT License                                         *
*--------------------------------------------------------------------------------------------*
* Copyright (c) 2026 erkan612                                                                *
*                                                                                            *
* Permission is hereby granted, free of charge, to any person obtaining a copy of this       *
* software and associated documentation files (the "Software"), to deal in the Software      *
* without restriction, including without limitation the rights to use, copy, modify, merge,  *
* publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons *
* to whom the Software is furnished to do so, subject to the following conditions:           *
*                                                                                            *
* The above copyright notice and this permission notice shall be included in all copies or   *
* substantial portions of the Software.                                                      *
*                                                                                            *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,        *
* INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR   *
* PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE  *
* FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR       *
* OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER     *
* DEALINGS IN THE SOFTWARE.                                                                  *
**********************************************************************************************
*--------------------------------------------------------------------------------------------*
*   					 *********************************************                       *
*   					  ██████╗ ███╗   ███╗██╗   ██╗███████╗██╗  ██╗		                 *
*   					 ██╔════╝ ████╗ ████║██║   ██║██╔════╝╚██╗██╔╝		                 *
*   					 ██║  ███╗██╔████╔██║██║   ██║█████╗   ╚███╔╝ 		                 *
*   					 ██║   ██║██║╚██╔╝██║╚██╗ ██╔╝██╔══╝   ██╔██╗ 		                 *
*   					 ╚██████╔╝██║ ╚═╝ ██║ ╚████╔╝ ███████╗██╔╝ ██╗		                 *
*   					  ╚═════╝ ╚═╝     ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝		                 *
*   						       GameMaker Vector Library									 *
*   						            Version 1.2.99					                     *
*   																                         *
*   						             by erkan612					                     *
*   					 *********************************************                       *
*********************************************************************************************/

// TODO: some show debug message logs needs to be improved and give more detail
// TODO: add more convenience functions, especially for svg importer and shear
// TODO: make the transform handling more user friendly
// TODO: CFF and OTF needs support, huge gaps needs to be filled, not a must now but worth adding in free time
// TODO: adding text render without font file requirement,
//       but i fear that might cost too much time than it should, 
//       still worth noting, if gets too complicated i might drop it, not a must anyway

function gmvex_init(tolerance = 0.5) {
    vertex_format_begin();
    vertex_format_add_position_3d();
    global.gmvex_vformat_pos = vertex_format_end();

    vertex_format_begin();
    vertex_format_add_position_3d();
    vertex_format_add_colour();
    vertex_format_add_texcoord();
    global.gmvex_vformat_full = vertex_format_end();

    global.gmvex_tolerance = tolerance;
}

function gmvex_set_tolerance(tol) {
    global.gmvex_tolerance = tol;
}