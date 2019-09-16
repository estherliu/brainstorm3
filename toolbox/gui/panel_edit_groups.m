function varargout = panel_edit_groups(varargin)
% PANEL_EDIT_GROUPS:  Edit user group memberships.
% USAGE:  [bstPanelNew, panelName] = panel_edit_groups('CreatePanel')

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
% Authors: Martin Cousineau, 2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.list.*;
    import matlab.net.*;
    import matlab.net.http.*;
    
    global GlobalData;
    % Constants
    panelName = 'EditGroups';
    
    % Create main panel
    jPanelNew = gui_river([0 0], [0 0 0 0], 'Groups');
    
    % Create Group
    jPanelCreate = gui_river([5 0], [0 2 0 2]);
    jTextGroup=gui_component('Text',  jPanelCreate, 'br hfill', '', [], [], []);
    gui_component('Button', jPanelCreate, [], 'Create Group', [], [], @ButtonCreateGroup_Callback);
    jPanelNew.add('br hfill', jPanelCreate);
    
    % Main panel
    jPanelMain = gui_river([5 0], [0 2 0 2]);
    jPanelNew.add('br hfill', jPanelMain);
    
    % Font size for the lists
    fontSize = round(10 * bst_get('InterfaceScaling') / 100);
    
    % List of groups
    jListGroups = JList();
    jListGroups.setCellRenderer(BstStringListRenderer(fontSize));
    jListGroups.setPreferredSize(java_scaled('dimension', 100, 250));
    java_setcb(jListGroups, 'ValueChangedCallback', @GroupListValueChanged_Callback);
    jPanelGroupsScrollList = JScrollPane();
    jPanelGroupsScrollList.getLayout.getViewport.setView(jListGroups);
    jPanelMain.add('hfill', jPanelGroupsScrollList);

    % List of members
    jPanelMembers = gui_river([5 0], [0 2 0 2], 'Members');
    jListMembers = JList();
    jListMembers.setCellRenderer(BstStringListRenderer(fontSize));
    jPanelMembersScrollList = JScrollPane();
    jPanelMembersScrollList.getLayout.getViewport.setView(jListMembers);
    jPanelMembers.add('hfill', jPanelMembersScrollList);
    jPanelMain.add('hfill', jPanelMembers);

    % Buttons
    jPanelButtons = gui_river([5 0], [0 2 0 2]);
    gui_component('Button', jPanelButtons, [], 'Add', [], [], @ButtonAddMember_Callback);
    gui_component('Button', jPanelButtons, 'hfill', 'Edit permissions', [], [], @ButtonEditMember_Callback);
    gui_component('Button', jPanelButtons, [], 'Remove', [], [], @ButtonRemoveMember_Callback);
    jPanelNew.add('br hfill', jPanelButtons);

    % ===== LOAD DATA =====
    UpdateGroupsList();
    UpdateMembersList();

    % ===== CREATE PANEL =====   
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jListGroups',  jListGroups, ...
                                  'jListMembers', jListMembers));

    %% ===== UPDATE GROUPS LIST =====
    function UpdateGroupsList()
        % Load groups
        groups = LoadGroups();
        % Remove JList callback
        bakCallback = java_getcb(jListGroups, 'ValueChangedCallback');
        java_setcb(jListGroups, 'ValueChangedCallback', []);

        % Create a new empty list
        listModel = java_create('javax.swing.DefaultListModel');
        % Add an item in list for each group
        for i = 1:length(groups)
            listModel.addElement(groups{i});
        end
        % Update list model
        jListGroups.setModel(listModel);

        % Restore callback
        drawnow
        java_setcb(jListGroups, 'ValueChangedCallback', bakCallback);
    end

    %% ===== UPDATE MEMBERS LIST =====
    function UpdateMembersList()
        % Load members
       
        group = jListGroups.getSelectedValue();
        
        
        [members, permissions] = LoadMembers(group);
        if isempty(group) || isempty(members)
            return
        end
        % Remove JList callback
        bakCallback = java_getcb(jListMembers, 'ValueChangedCallback');
        java_setcb(jListMembers, 'ValueChangedCallback', []);

        % Create a new empty list
        listModel = java_create('javax.swing.DefaultListModel');
        % Add an item in list for each group
        for i = 1:length(members)
            element=strcat(members{i},'  [')
            element=strcat(element,permissions{i});
            element=strcat(element, ']');
            listModel.addElement(element);            
%             listModel.addElement([string(members{i}) ' [' string(permissions{i}) ']']);
        end
        % Update list model
        jListMembers.setModel(listModel);

        % Restore callback
        drawnow
        java_setcb(jListMembers, 'ValueChangedCallback', bakCallback);
    end


    %% =================================================================================
    %  === CONTROLS CALLBACKS  =========================================================
    %  =================================================================================

    function GroupListValueChanged_Callback(h, ev)
        UpdateMembersList();
    end

    %% ===== BUTTON: CREATE GROUP =====
    function ButtonCreateGroup_Callback(varargin)
        import matlab.net.*;
        import matlab.net.http.*;
        
        groupname=jTextGroup.getText();
        if strcmp(groupname,'')~=1
            data=struct('Name',char(groupname));
            body=MessageBody(data);
            type1 = MediaType('text/*');
            type2 = MediaType('application/json','q','.5');
            acceptField = matlab.net.http.field.AcceptField([type1 type2]);
            h1 = HeaderField('Content-Type','application/json');
            h2 = HeaderField('sessionid',bst_get('SessionId'));
            h3 = HeaderField('deviceid',bst_get('DeviceId'));
            header = [acceptField,h1,h2,h3];
            method = RequestMethod.POST;
            r = RequestMessage(method,header,body);
    %         contentTypeField = matlab.net.http.field.ContentTypeField('application/json');

            show(r);

            url=string(bst_get('UrlAdr'))+"/group/create";
            disp([url]);
            gui_hide('Preferences');
            uri= URI(url);       
            try
                [resp,~,hist]=send(r,uri);
                status = resp.StatusCode;
                txt=char(status);
                if strcmp(txt,'200')==1 ||strcmp(txt,'OK')==1
                    content=resp.Body;                      
                    show(content);
                    %{
                    session=strtok(string(content),',');
                    session=char(extractAfter(session,":"));
                    %}
    %                 session = jsondecode(content.Data);
    %                 disp(session);
    %                 bst_set('SessionId',string(session(1).sessionid));
                    java_dialog('msgbox', 'Create group successfully!');
                    %UpdatePanel();
                    UpdateGroupsList();

                elseif strcmp(txt,'500')==1 ||strcmp(txt,'InternalServerError')==1
                    java_dialog('warning', 'Group already exist, change another name!');
                else
                    java_dialog('warning', txt);
                end
            catch
                java_dialog('warning', 'Create user groups failed! Check your url!');
            end
        else
            java_dialog('warning', 'Groupname cannot be empty!');
        end
        
        
    end

    %% ===== BUTTON: ADD MEMBER =====
    function ButtonAddMember_Callback(varargin)
        group = jListGroups.getSelectedValue();
        if isempty(group)
            return
        end

        [res, isCancel] = java_dialog('input', 'What is the name or email of the person you would like to add?', 'Add member', jPanelNew);
        if ~isCancel && ~isempty(res)
            [permission, isCancel2] = java_dialog('combo', 'What permissions would you like to give this member?', 'Edit permissions', [], {'Read-only','Read & write', 'Admin'});
            respass={res,permission};
            disp(respass);
            if ~isCancel2
                [res, error] = AddMember(group, respass);
                if res
                    UpdateMembersList();
                else
                    java_dialog('error', error, 'Add member');
                end
            end
        end
    end

    %% ===== BUTTON: EDIT PERMISSIONS =====
    function ButtonEditMember_Callback(varargin)
        group = jListGroups.getSelectedValue();
        member = ExtractMemberName(jListMembers.getSelectedValue());
        if isempty(group) || isempty(member)
            return
        end

        [res, isCancel] = java_dialog('combo', 'What permissions would you like to give this member?', 'Edit permissions', [], {'Read-only','Read & write', 'Admin'});
        if ~isCancel
            
            disp(['TODO: Edit permissions of member "' member '" of group "' group '" to "' res '"']);
            import matlab.net.*;
            import matlab.net.http.*;

            type1 = MediaType('text/*');
            type2 = MediaType('application/json','q','.5');
            acceptField = matlab.net.http.field.AcceptField([type1 type2]);
            h1 = HeaderField('Content-Type','application/json');
            h2 = HeaderField('sessionid',bst_get('SessionId'));
            h3 = HeaderField('deviceid',bst_get('DeviceId'));
            header = [acceptField,h1,h2,h3];
            method = RequestMethod.POST;
            
            if strcmp(res,'admin')==1
                permission=1
            elseif strcmp(res,'Read-only')==1
                permission=3
            else
                permission=2
            end
            data = struct('GroupName',group,'UserEmail',member,Role,permission);
            body=MessageBody(data);
            show(body);
            request_message = RequestMessage(method,header,body);
            show(request_message);
            serveradr = string(bst_get('UrlAdr'));
            url=strcat(serveradr,"/group/changerole");
            disp(url);
            try
                [resp,~,hist]=send(request_message,URI(url));
                status = resp.StatusCode;
                txt=char(status);
                if strcmp(status,'200')==1 ||strcmp(txt,'OK')==1
                    content = resp.Body;
                    show(content);
                    java_dialog('msgbox', 'Change role successfully!');
                    UpdateMembersList();
                elseif strcmp(txt,'401')==1 || strcmp(txt,'Unauthorized')==1
                    java_dialog('warning', 'Sorry. Your do not have permission!');
                else
                    java_dialog('error', txt);
                end
            catch
                java_dialog('warning', 'Change role failed! Check your url!');
            end
        end
    end

    %% ===== BUTTON: REMOVE MEMBER =====
    function ButtonRemoveMember_Callback(varargin)
        member = ExtractMemberName(jListMembers.getSelectedValue());
        group=jListGroups.getSelectedValue();
        if isempty(member)
            return
        end
        disp(['TODO: Remove member "' member '"']);
        import matlab.net.*;
        import matlab.net.http.*;

        type1 = MediaType('text/*');
        type2 = MediaType('application/json','q','.5');
        acceptField = matlab.net.http.field.AcceptField([type1 type2]);
        h1 = HeaderField('Content-Type','application/json');
        h2 = HeaderField('sessionid',bst_get('SessionId'));
        h3 = HeaderField('deviceid',bst_get('DeviceId'));
        header = [acceptField,h1,h2,h3];
        method = RequestMethod.POST;

        data = struct('GroupName',group,'UserEmail',member);
        body=MessageBody(data);
        show(body);
        request_message = RequestMessage(method,header,body);
        show(request_message);
        serveradr = string(bst_get('UrlAdr'));
        url=strcat(serveradr,"/group/removeuser");
        disp(url);
        try
            [resp,~,hist]=send(request_message,URI(url));
            status = resp.StatusCode;
            txt=char(status);
            if strcmp(status,'200')==1 ||strcmp(txt,'OK')==1
                content = resp.Body;
                show(content);
                java_dialog('msgbox', 'Remove group member successfully!');
                UpdateMembersList();
            elseif strcmp(txt,'401')==1 || strcmp(txt,'Unauthorized')==1
                java_dialog('warning', 'Sorry. Your do not have permission!');
            else
                java_dialog('error', txt);
            end
        catch
            java_dialog('warning', 'Remove group member failed! Check your url!');
        end
    end

    %% ===== LOAD GROUPS =====
    function groups = LoadGroups()

        import matlab.net.*;
        import matlab.net.http.*;
        groups = cell(0);

        type1 = MediaType('text/*');
        type2 = MediaType('application/json','q','.5');
        acceptField = matlab.net.http.field.AcceptField([type1 type2]);
        h1 = HeaderField('Content-Type','application/json');
        h2 = HeaderField('sessionid',bst_get('SessionId'));
        h3 = HeaderField('deviceid',bst_get('DeviceId'));
        header = [acceptField,h1,h2,h3];
        method = RequestMethod.POST;
        data = struct('start',0,'count',100, 'order', 0);
        body=MessageBody(data);
        show(body);
        request_message = RequestMessage(method,header,body);
        show(request_message);
        serveradr = string(bst_get('UrlAdr'));
        url=strcat(serveradr,"/user/listgroups");
        disp(url);
        gui_hide('Preferences');
        try
            [resp,~,hist]=send(request_message,URI(url));
            status = resp.StatusCode;
            txt=char(status);
            if strcmp(status,'200')==1 ||strcmp(txt,'OK')==1
                content = resp.Body;
                show(content);
                responseData = jsondecode(content.Data);
                if(size(responseData) > 0)
                    groups = cell(size(responseData));
                    for i = 1 : size(responseData)
                        groups{i} = responseData(i).name;
                    end
                end
                %UpdatePanel();
                disp('Load user groups successfully!');
                %java_dialog('msgbox', 'Load user groups successfully!');
            else
                java_dialog('error', txt);
            end
        catch
            java_dialog('warning', 'Load user groups failed! Check your url!');
        end
        %groups = {'NeuroSPEED', 'OMEGA', 'Ste-Justine Project'};
    end
    %% ===== LOAD MEMBERS =====
    function [members, permissions] = LoadMembers(group)
        import matlab.net.*;
        import matlab.net.http.*;
        if isempty(group)
            members = [];
            permissions = [];
            return
        end

        type1 = MediaType('text/*');
        type2 = MediaType('application/json','q','.5');
        acceptField = matlab.net.http.field.AcceptField([type1 type2]);
        h1 = HeaderField('Content-Type','application/json');
        h2 = HeaderField('sessionid',bst_get('SessionId'));
        h3 = HeaderField('deviceid',bst_get('DeviceId'));
        header = [acceptField,h1,h2,h3];
        method = RequestMethod.POST;
        data = struct('start',0,'count',100, 'order', 0);
        body=MessageBody(data);
        show(body);
        request_message = RequestMessage(method,header,body);
        show(request_message);
        serveradr = string(bst_get('UrlAdr'));
        url=strcat(serveradr,"/group/detail/");
        url=strcat(url,string(group));
        
        disp(url);
        gui_hide('Preferences');
        try
            [resp,~,hist]=send(request_message,URI(url));
            status = resp.StatusCode;
            txt=char(status);
            if strcmp(status,'200')==1 ||strcmp(txt,'OK')==1
                content = resp.Body;
                show(content);
                responseData = jsondecode(content.Data);
                if(size(responseData) > 0)
                    members = cell(size(responseData(1).groupMembers));
                    permissions = cell(size(responseData(1).groupMembers));
                    for i = 1 : size(responseData(1).groupMembers)
                        firstname = responseData(1).groupMembers(i).firstName;
                        lastname = responseData(1).groupMembers(i).lastName;
                        privilege = responseData(1).groupMembers(i).privilege;
                        name=strcat(firstname," ");
                        name=strcat(name,lastname);
                        members{i} = string(name);
                        if privilege==1
                            permissions{i}='admin'
                        elseif privilege==2
                            permissions{i}='write'
                        else
                            permissions{i}='read'
                        end
                    end
                end
                %UpdatePanel();
%                 java_dialog('msgbox', 'Load group member successfully!');
            else
                java_dialog('error', txt);
            end
        catch
            java_dialog('warning', 'Load groups member failed! Check your url!');
        end
%         members = {'Martin Cousineau', 'Sylvain Baillet', 'Marc Lalancette'};
%         permissions = {'admin', 'write', 'read'};
    end
    %% ===== ADD MEMBER TO GROUP =====
    function [res, error] = AddMember(group, member)
        import matlab.net.*;
        import matlab.net.http.*;
        error = [];
        res=1;
        
        type1 = MediaType('text/*');
        type2 = MediaType('application/json','q','.5');
        acceptField = matlab.net.http.field.AcceptField([type1 type2]);
        h1 = HeaderField('Content-Type','application/json');
        h2 = HeaderField('sessionid',bst_get('SessionId'));
        h3 = HeaderField('deviceid',bst_get('DeviceId'));
        header = [acceptField,h1,h2,h3];
        method = RequestMethod.POST;
        if strcmp(member(2),'admin')==1
            permission=1
        elseif strcmp(member(2),'Read-only')==1
            permission=3
        else
            permission=2
        end
        data = struct('GroupName',group,'UserEmail',member(1), 'Privilege', permission);
        body=MessageBody(data);
        show(body);
        request_message = RequestMessage(method,header,body);
        show(request_message);
        serveradr = string(bst_get('UrlAdr'));
        url=strcat(serveradr,"/group/adduser");
        disp(url);
        try
            [resp,~,hist]=send(request_message,URI(url));
            status = resp.StatusCode;
            txt=char(status);
            if strcmp(status,'200')==1 ||strcmp(txt,'OK')==1
                content = resp.Body;
                show(content);
                %UpdatePanel();
                java_dialog('msgbox', 'Add group member successfully!');
            else
                java_dialog('error', txt);
            end
        catch
            java_dialog('warning', 'Add group member failed! Check your url!');
        end
        %error = 'Could not find member.';
    end
end

% Extract member name if permission present in brackets
function member = ExtractMemberName(member)
    iPermission = strfind(member, ' [');
    if ~isempty(iPermission) && iPermission > 2
        member = member(1:iPermission(end)-1);
    end
end


