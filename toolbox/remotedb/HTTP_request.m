function [response, status] = HTTP_request(method,header,data,url,checksession)
% HTTP_REQUEST: POST,GET request to construct interaction between front end
% and back end.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Zeyu Chen, Chaoyi Liu 2019
    import matlab.net.*;
    import matlab.net.http.*;
    
    
    contentTypeField = matlab.net.http.field.ContentTypeField('application/json');
    type1 = matlab.net.http.MediaType('text/*');
    type2 = matlab.net.http.MediaType('application/json','q','.5');
    acceptField = matlab.net.http.field.AcceptField([type1 type2]);
    jsonheader = HeaderField('Content-Type','application/json');
    sessionheader = HeaderField('sessionid',bst_get('SessionId'));
    deviceheader = HeaderField('deviceid',bst_get('DeviceId'));
    streamheader = HeaderField('Content-Type','application/octet-stream');
    protocolheader = HeaderField('protocolid',bst_get('ProtocolId'));
    headerNone=0;
    switch (header)
        case 'None'
            headerNone=1;
            header = [acceptField,contentTypeField];
            body=MessageBody(data);
        case 'Default'
            header = [acceptField,jsonheader,sessionheader,deviceheader,protocolheader];
            body=MessageBody(data);
        case 'Stream'
            header = [streamheader,sessionheader,deviceheader,protocolheader];
            body=data;
    end
    
    if checksession==1
        [sessionon] = bst_call(@Checksession);
        if sessionon==0
            response = {};
            status = "Session unavailable";
            disp("Please log in first!");
            bst_set('SessionId',[]);
            return 
        end
    end
    
    if isempty(bst_get('SessionId')) && headerNone~=1
         response = {};
         status = "Session unavailable";
         disp("Please log in first!");
         return 
    end
    
    if strcmp(method,"POST")==1
        method =RequestMethod.POST;   
        r=RequestMessage(method,header,body);
    elseif  strcmp(method,"GET")==1
        method =RequestMethod.GET;
        r=RequestMessage(method,header);
    else
        java_dialog('warning',"wrong method");
        return;
    end
    %Debug uncomment below
    %disp(url);
    %disp(data);
    uri= URI(url); 
    try
        [resp,~,hist]=send(r,uri);
        response = resp; 
        status = char(resp.StatusCode);
    catch
        response = {};
        status = "Fail to connect to server.";
    end
    

end

