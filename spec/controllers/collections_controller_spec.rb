# Copyright 2011-2018, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

require 'rails_helper'

describe Admin::CollectionsController, type: :controller do
  render_views

  describe 'security' do
    let(:collection) { FactoryGirl.create(:collection) }
    before do
      ApiToken.create token: 'secret_token', username: 'archivist1@example.com', email: 'archivist1@example.com'
    end
    describe 'ingest api' do
      it "all routes should return 401 when no token is present" do
        expect(get :index, format: 'json').to have_http_status(401)
        expect(get :show, id: collection.id, format: 'json').to have_http_status(401)
        expect(get :items, id: collection.id, format: 'json').to have_http_status(401)
        expect(post :create, format: 'json').to have_http_status(401)
        expect(put :update, id: collection.id, format: 'json').to have_http_status(401)
      end
      it "all routes should return 403 when a bad token in present" do
        request.headers['Avalon-Api-Key'] = 'badtoken'
        expect(get :index, format: 'json').to have_http_status(403)
        expect(get :show, id: collection.id, format: 'json').to have_http_status(403)
        expect(get :items, id: collection.id, format: 'json').to have_http_status(403)
        expect(post :create, format: 'json').to have_http_status(403)
        expect(put :update, id: collection.id, format: 'json').to have_http_status(403)
      end
    end
    describe 'normal auth' do
      context 'with end-user' do
        before do
          login_as :user
        end
        #New is isolated here due to issues caused by the controller instance not being regenerated
        it "should redirect to /" do
          expect(get :new).to redirect_to(root_path)
        end
        it "all routes should redirect to /" do
          expect(get :index).to redirect_to(root_path)
          expect(get :show, id: collection.id).to redirect_to(root_path)
          expect(get :edit, id: collection.id).to redirect_to(root_path)
          expect(get :remove, id: collection.id).to redirect_to(root_path)
          expect(post :create).to redirect_to(root_path)
          expect(put :update, id: collection.id).to redirect_to(root_path)
          expect(patch :update, id: collection.id).to redirect_to(root_path)
          expect(delete :destroy, id: collection.id).to redirect_to(root_path)
        end
      end
    end
  end

  describe "#manage" do
    let!(:collection) { FactoryGirl.create(:collection) }
    before(:each) do
      request.env["HTTP_REFERER"] = '/'
      login_as(:administrator)
    end

    it "should add users to manager role" do
      manager = FactoryGirl.create(:manager)
      put 'update', id: collection.id, submit_add_manager: 'Add', add_manager: manager.user_key
      collection.reload
      expect(manager).to be_in(collection.managers)
    end

    it "should not add users to manager role" do
      user = FactoryGirl.create(:user)
      put 'update', id: collection.id, submit_add_manager: 'Add', add_manager: user.user_key
      collection.reload
      expect(user).not_to be_in(collection.managers)
      expect(flash[:error]).not_to be_empty
    end

    it "should remove users from manager role" do
      #initial_manager = FactoryGirl.create(:manager).user_key
      collection.managers += [FactoryGirl.create(:manager).user_key, FactoryGirl.create(:manager).user_key]
      collection.save!
      manager = User.where(Devise.authentication_keys.first => collection.managers.first).first
      put 'update', id: collection.id, remove_manager: manager.user_key
      collection.reload
      expect(manager).not_to be_in(collection.managers)
    end
  end

  describe "#edit" do
    let!(:collection) { FactoryGirl.create(:collection) }
    before(:each) do
      request.env["HTTP_REFERER"] = '/'
    end

    it "should add users to editor role" do
      login_as(:administrator)
      editor = FactoryGirl.build(:user)
      put 'update', id: collection.id, submit_add_editor: 'Add', add_editor: editor.user_key
      collection.reload
      expect(editor).to be_in(collection.editors)
    end

    it "should remove users from editor role" do
      login_as(:administrator)
      editor = User.where(Devise.authentication_keys.first => collection.editors.first).first
      put 'update', id: collection.id, remove_editor: editor.user_key
      collection.reload
      expect(editor).not_to be_in(collection.editors)
    end
  end

  describe "#deposit" do
    let!(:collection) { FactoryGirl.create(:collection) }
    before(:each) do
      request.env["HTTP_REFERER"] = '/'
    end

    it "should add users to depositor role" do
      login_as(:administrator)
      depositor = FactoryGirl.build(:user)
      put 'update', id: collection.id, submit_add_depositor: 'Add', add_depositor: depositor.user_key
      collection.reload
      expect(depositor).to be_in(collection.depositors)
    end

    it "should remove users from depositor role" do
      login_as(:administrator)
      depositor = User.where(Devise.authentication_keys.first => collection.depositors.first).first
      put 'update', id: collection.id, remove_depositor: depositor.user_key
      collection.reload
      expect(depositor).not_to be_in(collection.depositors)
    end
  end

  describe "#index" do
    let!(:collection) { FactoryGirl.create(:collection) }
    subject(:json) { JSON.parse(response.body) }
    before do
      ApiToken.create token: 'secret_token', username: 'archivist1@example.com', email: 'archivist1@example.com'
      request.headers['Avalon-Api-Key'] = 'secret_token'
    end
    it "should return list of collections" do
      get 'index', format:'json'
      expect(json.count).to eq(1)
      expect(json.first['id']).to eq(collection.id)
      expect(json.first['name']).to eq(collection.name)
      expect(json.first['unit']).to eq(collection.unit)
      expect(json.first['description']).to eq(collection.description)
      expect(json.first['object_count']['total']).to eq(collection.media_objects.count)
      expect(json.first['object_count']['published']).to eq(collection.media_objects.reject{|mo| !mo.published?}.count)
      expect(json.first['object_count']['unpublished']).to eq(collection.media_objects.reject{|mo| mo.published?}.count)
      expect(json.first['roles']['managers']).to eq(collection.managers)
      expect(json.first['roles']['editors']).to eq(collection.editors)
      expect(json.first['roles']['depositors']).to eq(collection.depositors)
    end
    it "should return list of collections for good user" do
      get 'index', user: collection.managers.first, format:'json'
      expect(json.count).to eq(1)
    end
    it "should return no collections for bad user" do
      get 'index', user: 'foobar', format:'json'
      expect(json.count).to eq(0)
    end
  end

  describe 'pagination' do
    subject(:json) { JSON.parse(response.body) }
    before do
      ApiToken.create token: 'secret_token', username: 'archivist1@example.com', email: 'archivist1@example.com'
      request.headers['Avalon-Api-Key'] = 'secret_token'
    end
    it 'should paginate index' do
      5.times { FactoryGirl.create(:collection) }
      get 'index', format:'json', per_page: '2'
      expect(json.count).to eq(2)
      expect(response.headers['Per-Page']).to eq('2')
      expect(response.headers['Total']).to eq('5')
    end
    it 'should paginate collection/items' do
      collection = FactoryGirl.create(:collection, items: 5)
      get 'items', id: collection.id, format: 'json', per_page: '2'
      expect(json.count).to eq(2)
      expect(response.headers['Per-Page']).to eq('2')
      expect(response.headers['Total']).to eq('5')
    end
  end

  describe "#show" do
    let!(:collection) { FactoryGirl.create(:collection) }

    it "should allow access to managers" do
      login_user(collection.managers.first)
      get 'show', id: collection.id
      expect(response).to be_ok
    end

    context "with json format" do
      subject(:json) { JSON.parse(response.body) }

      it "should return json for specific collection" do
        ApiToken.create token: 'secret_token', username: 'archivist1@example.com', email: 'archivist1@example.com'
        request.headers['Avalon-Api-Key'] = 'secret_token'
        get 'show', id: collection.id, format:'json'
        expect(json['id']).to eq(collection.id)
        expect(json['name']).to eq(collection.name)
        expect(json['unit']).to eq(collection.unit)
        expect(json['description']).to eq(collection.description)
        expect(json['object_count']['total']).to eq(collection.media_objects.count)
        expect(json['object_count']['published']).to eq(collection.media_objects.reject{|mo| !mo.published?}.count)
        expect(json['object_count']['unpublished']).to eq(collection.media_objects.reject{|mo| mo.published?}.count)
        expect(json['roles']['managers']).to eq(collection.managers)
        expect(json['roles']['editors']).to eq(collection.editors)
        expect(json['roles']['depositors']).to eq(collection.depositors)
      end

      it "should return 404 if requested collection not present" do
        ApiToken.create token: 'secret_token', username: 'archivist1@example.com', email: 'archivist1@example.com'
        request.headers['Avalon-Api-Key'] = 'secret_token'
        get 'show', id: 'doesnt_exist', format: 'json'
        expect(response.status).to eq(404)
        expect(JSON.parse(response.body)["errors"].class).to eq Array
        expect(JSON.parse(response.body)["errors"].first.class).to eq String
      end
    end
  end

  describe "#items" do
    let!(:collection) { FactoryGirl.create(:collection, items: 2) }

    it "should return json for specific collection's media objects" do
      ApiToken.create token: 'secret_token', username: 'archivist1@example.com', email: 'archivist1@example.com'
      request.headers['Avalon-Api-Key'] = 'secret_token'
      get 'items', id: collection.id, format: 'json'
      expect(JSON.parse(response.body)).to include(collection.media_objects[0].id,collection.media_objects[1].id)
      #TODO add check that mediaobject is serialized to json properly
    end

  end

  describe "#create" do
    let!(:collection) { FactoryGirl.build(:collection) }
    before do
      ApiToken.create token: 'secret_token', username: 'archivist1@example.com', email: 'archivist1@example.com'
      request.headers['Avalon-Api-Key'] = 'secret_token'
    end

    it "should notify administrators" do
      login_as(:administrator) #otherwise, there are no administrators to mail
      # mock_email = double('email')
      # allow(mock_email).to receive(:deliver_later)
      # expect(NotificationsMailer).to receive(:new_collection).and_return(mock_email)
      # FIXME: This delivers two instead of one for some reason
      expect {post 'create', format:'json', admin_collection: {name: collection.name, description: collection.description, unit: collection.unit, managers: collection.managers}}.to change { ActionMailer::Base.deliveries.count }
      # post 'create', format:'json', admin_collection: {name: collection.name, description: collection.description, unit: collection.unit, managers: collection.managers}
    end
    it "should create a new collection" do
      post 'create', format:'json', admin_collection: {name: collection.name, description: collection.description, unit: collection.unit, managers: collection.managers}
      expect(JSON.parse(response.body)['id'].class).to eq String
      expect(JSON.parse(response.body)).not_to include('errors')
    end
    it "should return 422 if collection creation failed" do
      post 'create', format:'json', admin_collection: {name: collection.name, description: collection.description, unit: collection.unit}
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)).to include('errors')
      expect(JSON.parse(response.body)["errors"].class).to eq Array
      expect(JSON.parse(response.body)["errors"].first.class).to eq String
    end

  end

  describe "#update" do
    it "should notify administrators if name changed" do
      login_as(:administrator) #otherwise, there are no administrators to mail
      # mock_delay = double('mock_delay').as_null_object
      # allow(NotificationsMailer).to receive(:deliver_later).and_return(mock_delay)
      # expect(mock_delay).to receive(:update_collection)
      @collection = FactoryGirl.create(:collection)
      # put 'update', id: @collection.id, admin_collection: {name: "#{@collection.name}-new", description: @collection.description, unit: @collection.unit}
      # FIXME: This delivers two instead of one for some reason
      expect {put 'update', id: @collection.id, admin_collection: {name: "#{@collection.name}-new", description: @collection.description, unit: @collection.unit}}.to change { ActionMailer::Base.deliveries.count }

    end

    context "update REST API" do
      let!(:collection) { FactoryGirl.create(:collection)}
      before do
        ApiToken.create token: 'secret_token', username: 'archivist1@example.com', email: 'archivist1@example.com'
        request.headers['Avalon-Api-Key'] = 'secret_token'
      end

      it "should update a collection via API" do
        old_description = collection.description
        put 'update', format: 'json', id: collection.id, admin_collection: {description: collection.description+'new'}
        expect(JSON.parse(response.body)['id'].class).to eq String
        expect(JSON.parse(response.body)).not_to include('errors')
        collection.reload
        expect(collection.description).to eq old_description+'new'
      end
      it "should return 422 if collection update via API failed" do
        allow_any_instance_of(Admin::Collection).to receive(:save).and_return false
        put 'update', format: 'json', id: collection.id, admin_collection: {description: collection.description+'new'}
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)).to include('errors')
        expect(JSON.parse(response.body)["errors"].class).to eq Array
        expect(JSON.parse(response.body)["errors"].first.class).to eq String
      end
    end

    context "access controls" do
      let!(:collection) { FactoryGirl.create(:collection)}

      it "should not allow empty user" do
        expect{ put 'update', id: collection.id, submit_add_user: "Add", add_user: "", add_user_display: ""}.not_to change{ collection.reload.default_read_users.size }
      end

      it "should not allow empty class" do
        expect{ put 'update', id: collection.id, submit_add_class: "Add", add_class: "", add_class_display: ""}.not_to change{ collection.reload.default_read_groups.size }
      end

    end
  end

  describe "#remove" do
    let!(:collection) { FactoryGirl.create(:collection) }

    it "redirects with message when user does not have ability to delete collection" do
      login_as :user
      expect(controller.current_ability.can? :destroy, collection).to be_falsey
      expect(get :remove, id: collection.id).to redirect_to(root_path)
      expect(flash[:notice]).not_to be_empty
    end
    it "displays confirmation form for managers" do
      login_user collection.managers.first
      expect(controller.current_ability.can? :destroy, collection).to be_truthy
      expect(get :remove, id: collection.id).to render_template(:remove)
    end
  end
end
