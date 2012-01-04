# -*- coding: utf-8 -*-
require 'spec_helper'

describe EntriesController do
  fixtures :all

  def _login_and_change_month(year,month, current_action='items')
    login
    xhr :post, :change_month, :year=>'2008', :month=>'2', :current_action => current_action
  end

  describe "#index" do
    context "before login," do
      before do 
        get :index
      end

      it_should_behave_like "Unauthenticated Access"
    end

    context "after login," do
      before do
        login
      end
      
      context "when input values are invalid," do
        before do 
          get :index, :year=>'2008', :month=>'13'
        end

        subject { response }
        it { should redirect_to current_entries_url }
      end

      shared_examples_for "Success" do
        describe "response" do
          subject { response }
          it { should be_success }
          it { should render_template "index" }
        end
      end

      shared_examples_for "no params" do
          it_should_behave_like "Success"
          
          describe "@new_item" do
            subject { assigns(:new_item)}
            its(:action_date) { should == Date.today }
          end

          describe "@items" do
            subject { assigns(:items) }
            specify {
              subject.each do |item|
                item.action_date.should be_between(Date.today.beginning_of_month, Date.today.end_of_month)
              end
            }
          end
        
      end

      context "when year and month are not specified" do
        before do
          get :index
        end
        it_should_behave_like "no params"
      end
      
      context "when year and month are specified," do
        context "when year and month is today's ones" do 
          before do
            get :index, :year => Date.today.year, :month => Date.today.month
          end
          it_should_behave_like "no params"
        end

        context "when year and month is specified but they are not today's ones" do 
          before do
            get :index, :year => '2008', :month => '2'
          end

          it_should_behave_like "Success"
          
          describe "@new_item" do
            subject { assigns(:new_item)}
            its(:action_date) { should == Date.new(2008,2) }
          end

          describe "@items" do
            subject { assigns(:items) }
            specify {
              subject.each do |item|
                item.action_date.should be_between(Date.new(2008,2), Date.new(2008,2).end_of_month)
              end
            }
          end
        end
        
      end

      context "with tag," do
        before do
          tags = ['abc', 'def']
          xhr :put, :update, :id=>items(:item11).id.to_s, :item_name=>'テスト11', :action_year=>items(:item11).action_date.year.to_s, :action_month=>items(:item11).action_date.month.to_s, :action_day=>items(:item11).action_date.day.to_s, :amount=>"100000", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :tag_list => tags.join(" "), :year => items(:item11).action_date.year, :month => items(:item11).action_date.month
          
          get :index, :tag => 'abc'
        end

        describe "response" do
          subject { response }
          it { should be_success }
          it { should render_template 'index_with_tag' }
        end

        describe "@items" do
          subject { assigns(:items)}
          it { should have(1).items }
        end

        describe "@tag" do
          subject { assigns(:tag) }
          it { should be == 'abc' }
        end
      end

      context "with mark," do
        before do
          xhr :put, :update, :id=>items(:item11).id.to_s, :item_name=>'テスト11', :action_year=>items(:item11).action_date.year.to_s, :action_month=>items(:item11).action_date.month.to_s, :action_day=>items(:item11).action_date.day.to_s, :amount=>"100000", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :confirmation_required => '1', :year => items(:item11).action_date.year, :month => items(:item11).action_date.month
          get :index, :mark => 'confirmation_required'
        end

        describe "response" do 
          subject { response }
          it { should be_success }
          it { should render_template "index_with_mark" }
        end

        describe "@items" do
          subject { assigns(:items) }
          it { should have(Item.where(:confirmation_required => true).count).items }
          specify {
            subject.each do |item|
              item.should be_confirmation_required
            end
          }
        end
      end
      
      context "with filter change," do
        context "with valid filter_account_id" do 
          shared_examples_for "filtered index" do 
            describe "response" do
              subject { response }
              it { should be_success }
              it { should render_template 'index' }
            end

            describe "@items" do
              subject { assigns(:items)}
              specify {
                subject.each do |item|
                  [item.from_account_id, item.to_account_id].should include(accounts(:bank1).id)
                end
              }
            end

            describe "session[:filter_account_id]" do
              subject {  session[:filter_account_id] }
              it { should be == accounts(:bank1).id }
            end
          end

          before do
            xhr :get, :index, :filter_account_id => accounts(:bank1).id, :year => '2008', :month => '2'
          end
          
          it_should_behave_like "filtered index"

          context "after changing filter, access index with no filter_account_id," do
            before do
              xhr :get, :index, :year => '2008', :month => '2'
            end

            it_should_behave_like "filtered index"
          end

          context "after changing filter, access with filter_account_id nil" do 
            before do
              @non_bank1_item = Item.create!(:user_id => users(:user1).id, :name => "not bank1 entry", :action_date => Date.new(2008,2,15), :from_account_id => accounts(:income2).id, :to_account_id => accounts(:outgo3).id, :amount => 1000)
              session[:filter_account_id].should == accounts(:bank1).id
              xhr :get, :index, :filter_account_id => "", :year => '2008', :month => '2'
            end

            describe "session[:filter_account_id]" do
              subject {  session[:filter_account_id] }
              it { should be_nil }
            end

            describe "@items" do
              subject { assigns(:items) }
              it { should include(@non_bank1_item) }
            end
          end
        end
      end

      context "with params[:remaining] = true," do
        shared_examples_for "executed correctly" do 
          describe "response" do 
            subject { response }
            it { should be_success }
            it { should render_template "index" }
          end

          describe "@separated_accounts" do
            subject { assigns(:separated_accounts) }
            it { should_not be_nil }
          end
        end
        
        context "without other params," do
          describe "Item.find_partial" do
            it "is called with :remain => true" do
              stub_date_from = Date.new(2008,2)
              stub_date_to = Date.new(2008,2).end_of_month
              Date.should_receive(:new).with(2008,2).at_least(:once).and_return(stub_date_from)
              stub_date_from.should_receive(:end_of_month).at_least(:once).and_return(stub_date_to)
              
              Item.should_receive(:find_partial).with(an_instance_of(User),
                                                      stub_date_from, stub_date_to,
                                                      hash_including(:remain => true)).and_return(Item.where(:action_date => Date.new(2008,2)..Date.new(2008,2).end_of_month).all)
              xhr :get, :index, :remaining => 1, :year => 2008, :month => 2
            end
          end
          
          describe "other than Item.find_partial" do
            before do 
              Item.stub(:find_partial).and_return(Item.where(:action_date => Date.new(2008,2)..Date.new(2008,2).end_of_month).all)
              xhr :get, :index, :remaining => true, :year => 2008, :month => 2
            end
            
            it_should_behave_like "executed correctly"

            describe "@items" do
              subject { assigns(:items) }
              it { should_not be_empty }
            end
          end
        end
        
        context "and params[:tag] = 'xxx'," do
          describe "Item.find_partial" do
            it "called with tag => 'xxx' and :remain => true" do 
              Item.should_receive(:find_partial).with(an_instance_of(User),
                                                      nil, nil,
                                                      hash_including(:tag => 'xxx', :remain => true)).and_return(Item.where(:action_date => Date.new(2008,2)..Date.new(2008,2).end_of_month).all)
              xhr :get, :index, :remaining => true, :year => 2008, :month => 2, :tag => 'xxx'
            end
          end

          describe "other than Item.find_partial," do
            before do
              Item.stub(:find_partial).and_return(Item.where(:action_date => Date.new(2008,2)..Date.new(2008,2).end_of_month).all)
              xhr :get, :index, :remaining => true, :year => 2008, :month => 2, :tag => 'xxx'
            end

            it_should_behave_like "executed correctly"

            describe "@items" do
              subject { assigns(:items) }
              # 0 item for  remaining 
              it { should_not be_empty }
            end
          end
        end

        context "and invalid year and month in params," do
          before do
            xhr :get, :index, :remaining => true, :year => 2008, :month => 15
          end
          describe "response" do
            subject { response }
            it { should redirect_by_js_to current_entries_url }
          end
        end
      end
    end
  end

  describe "#edit" do
    context "before login," do
      before do
        xhr :get, :edit, :id => items(:item1).id.to_s
      end
      it_should_behave_like "Unauthenticated Access by xhr"
    end

    context "after login," do
      before do
        login
      end

      context "when id is missing," do
        before do
          xhr :get, :edit
        end

        subject { response }
        it { should redirect_by_js_to entries_url(:year => Date.today.year, :month => Date.today.month)}
      end

      [:item1, :adjustment2].each do |item_name|
        shared_examples_for "execute edit successfully of #{item_name.to_s}" do
          describe "resposne" do
            subject { response }
            it { should be_success }
            it { should render_template "edit" }
          end

          describe "@item" do
            subject { assigns(:item) }
            its(:id) { should be items(item_name).id }
          end
        end
      end

      context "with entry_id," do
        before do
          xhr :get, :edit, :id => items(:item1).id
        end
        it_should_behave_like "execute edit successfully of item1"
      end

      context "with adjustment_id," do
        before do
          xhr :get, :edit, :id => items(:adjustment2).id
        end
        it_should_behave_like "execute edit successfully of adjustment2"
      end
    end
  end

  describe "#show" do
    context "before login," do
      before do 
        xhr :get, :show, :id => items(:item1).id
      end
      it_should_behave_like "Unauthenticated Access by xhr"
    end

    context "after login," do
      before do
        _login_and_change_month(2008,2)
      end

      context "without id," do
        before do
          xhr :get, :show
        end
        subject { response }
        it { should redirect_by_js_to current_entries_url }
      end

      context "with valid id," do
        before do
          xhr :get, :show, :id => items(:item1).id
        end

        subject { response }
        it { should be_success }
        it { should render_template "show" }
      end
    end
  end

  describe "#new" do
    context "before login," do
      before do
        xhr :get, :new
      end

      it_should_behave_like "Unauthenticated Access by xhr"
    end

    context "after login," do
      before do
        _login_and_change_month(2008,2)
      end

      context "without any params" do
        before do
          xhr :get, :new
        end

        describe "response" do 
          subject { response }
          it { should be_success }
          it { should render_template "add_item" }
        end

        describe "@item" do
          subject { assigns(:item) }
          its(:action_date) { should == Date.today }
        end
      end

      context "with year and month in params" do
        before do
          xhr :get, :new, :year => '2008', :month => '5'
        end

        describe "response" do 
          subject { response }
          it { should be_success }
          it { should render_template "add_item" }
        end

        describe "@item" do
          subject { assigns(:item) }
          its(:action_date) { should == Date.new(2008,5) }
        end
      end

      context "with entry_type = adjustment in params," do
        shared_examples_for "respond successfully" do
          describe "response" do 
            subject {response}
            it { should be_success }
            it { should render_template 'add_adjustment'}
          end
        end
        
        context "and no year and month in params," do
          before do
            xhr :get, :new, :entry_type => 'adjustment'
          end
          
          it_should_behave_like "respond successfully"

          describe "@action_date" do
            subject { assigns(:action_date)}
            it { should == Date.today }
          end
        end
        
        context "and year and month in params," do
          context "and correct date is specified," do
            before do
              xhr :get, :new, :entry_type => 'adjustment', :year => '2009', :month => '5'
            end

            it_should_behave_like "respond successfully"

            describe "@action_date" do
              subject { assigns(:action_date)}
              it { should == Date.new(2009,5) }
            end
          end
          
          context "and invalid date is specified," do
            before do
              xhr :get, :new, :entry_type => 'adjustment', :year => '2009', :month => '15'
            end

            it_should_behave_like "respond successfully"

            describe "@action_date" do
              subject { assigns(:action_date)}
              it { should == Date.today }
            end
          end
        end
      end
      
      context "with entry_type = simple in params," do
        let(:mock_user) { users(:user1)}
        before do
          mock_user
          User.should_receive(:find).with(mock_user.id).and_return(mock_user)
          mock_user.should_receive(:get_separated_accounts).twice.and_return(:from_accounts => [['a', 'b'],['c','d']], :to_accounts => [['e','f'],['g','h']])
          
          @controller.should_receive(:form_authenticity_token).and_return("1234567")
          xhr :get, :new, :entry_type => 'simple'
        end
        
        describe "response" do 
          subject {response}
          it { should be_success }
          it { should render_template 'new_simple'}
        end

        describe "@data" do
          subject { assigns(:data) }
          its([:authenticity_token]) { should == "1234567" }
          its([:year]) { should == Date.today.year }
          its([:month]) { should == Date.today.month }
          its([:day]) { should == Date.today.day}
          its([:from_accounts]) { should == [{ "value" => 'b', "text" => 'a'}, { "value" => 'd', "text" => 'c'}]}
          its([:to_accounts]) { should == [{ "value" => 'f', "text" => 'e'}, { "value" => 'h', "text" => 'g'}]}
        end
      end
    end
  end

  describe "#destroy" do
    context "before login," do 
      before do 
        xhr :delete, :destroy, :id => 12345
      end
      subject {response}
      it {should redirect_by_js_to login_url }
    end

    context "after login," do
      let(:mock_user) { users(:user1)}
      before do
        mock_user
        User.should_receive(:find).with(mock_user.id).at_least(1).and_return(mock_user)
        login
      end

      context "when id in params is invalid," do
        let(:mock_items) { double }
        before do
          mock_user.should_receive(:items).and_return(mock_items)
          mock_items.should_receive(:find).with("12345").and_raise(ActiveRecord::RecordNotFound.new)
          xhr :delete, :destroy, :id => 12345
        end

        describe "response" do
          subject {response}
          it {should redirect_by_js_to entries_url(Date.today.year, Date.today.month)}
        end
      end

      context "when id in params is not specified," do
        let(:mock_items) { double('items') }
        before do
          mock_user.should_receive(:items).and_return(mock_items)
          mock_items.should_receive(:find).with(nil).and_raise(ActiveRecord::RecordNotFound.new)
          xhr :delete, :destroy
        end

        describe "response" do
          subject {response}
          it {should redirect_by_js_to login_url }
        end
      end

      context "item's is_adjustment is false" do
        context "given there is a future's adjustment," do
          before do
            @old_item1 = items(:item1)
            @old_adj2 = items(:adjustment2)
            @old_bank1pl = monthly_profit_losses(:bank1200802)
            @old_outgo3pl = monthly_profit_losses(:outgo3200802)

            _login_and_change_month(2008,2)

            xhr :delete, :destroy, :id => @old_item1.id, :year => @old_item1.action_date.year, :month => @old_item1.action_date.month
          end

          describe "response" do
            subject { response }
            it { should be_success }
            its(:content_type) { should == "text/javascript"}
          end

          describe "the specified item" do
            subject { Item.where(:id => @old_item1.id).all }
            it { should have(0).item }
          end
          
          describe "the future adjustment item" do
            subject { Item.find(@old_adj2.id) }
            its(:amount) { should == @old_adj2.amount - @old_item1.amount }
          end

          describe "amount of Montly profit loss of from_account" do
            subject { MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id) }
            its(:amount) { should == @old_bank1pl.amount }
          end

          describe "amount of Montly profit loss of to_account" do
            subject { MonthlyProfitLoss.find(monthly_profit_losses(:outgo3200802).id) }
            its(:amount) { should == @old_outgo3pl.amount - @old_item1.amount }
          end
        end

        context "given there is no future's adjustment," do
          before do
            _login_and_change_month(2008,2)
            xhr :post, :create, :item_name=>'test', :amount=>'1000', :action_year=>'2008', :action_month=>'2', :action_day=>'25',:from=>'11', :to=>'13', :year => 2008, :month => 2
            @item = Item.where(:name => 'test', :from_account_id => 11, :to_account_id => 13).first
            @old_bank11pl = MonthlyProfitLoss.find(:first, :conditions=>["account_id = ? and month = ?", 11, Date.new(2008,2)])
            @old_outgo13pl = MonthlyProfitLoss.find(:first, :conditions=>["account_id = ? and month = ?", 13, Date.new(2008,2)])
            
            xhr :delete, :destroy, :id => @item.id, :year => 2008, :month => 2
          end

          describe "response" do 
            subject { response }
            it { should be_success }
          end

          describe "amount of from_account" do 
            subject { MonthlyProfitLoss.find(@old_bank11pl.id) }
            its(:amount) { should == @old_bank11pl.amount + @item.amount}
          end

          describe "specified item" do

            it "should does not exist" do 
              expect{ Item.find(@item.id) }.to raise_error(ActiveRecord::RecordNotFound)
            end
            
          end

          describe "amount of to_account" do
            subject { MonthlyProfitLoss.find(@old_outgo13pl.id) }
            its(:amount) {should ==  @old_outgo13pl.amount - @item.amount }
          end
        end

        context "when destroy the item which is assigned to credit card account," do
          before do
            _login_and_change_month(2008,2)
            # dummy data
            xhr :post, :create, :item_name=>'test', :amount=>'1000', :action_year=>'2008', :action_month=>'2', :action_day=>'10',:from=>'4', :to=>'3', :year => 2008, :month => 2
            @item = Item.find(:first, :conditions=>["name = 'test' and from_account_id = 4 and to_account_id = 3"])
            @child_item = Item.find(@item.child_id)
            xhr :delete, :destroy, :id => @item.id, :year => 2008, :month => 2
          end

          describe "response" do 
            subject { response }
            it { should be_success }
          end

          describe "specified item" do
            it 'should not exist' do 
              expect {Item.find(@item.id)}.to raise_error(ActiveRecord::RecordNotFound)
            end
          end

          describe "child item of the specified item" do
            it 'should not exist' do 
              expect {Item.find(@child_item.id)}.to raise_error(ActiveRecord::RecordNotFound)
            end
          end
        end

        context "when is_adjustment is true," do
          context "with invalid id," do
            let(:mock_items) { double }
            before do
              mock_user.should_receive(:items).and_return(mock_items)
              mock_items.should_receive(:find).with("20000").and_raise(ActiveRecord::RecordNotFound.new)
              xhr :delete, :destroy, :id => 20000, :year => Date.today.year, :month => Date.today.month
            end
            subject {response}
            it {should redirect_by_js_to entries_url(Date.today.year, Date.today.month)}
          end

          context "with correct id," do
            context "adj2を変更する。影響をうけるのはadj4のみ。mplには影響なし," do
              before do
                _login_and_change_month(2008,2)
                
                @init_adj2 = Item.find(items(:adjustment2).id)
                @init_adj4 = Item.find(items(:adjustment4).id)
                @init_adj6 = Item.find(items(:adjustment6).id)
                @init_bank_pl = monthly_profit_losses(:bank1200802)
                @init_bank_pl = monthly_profit_losses(:bank1200802)
                @init_unknown_pl = MonthlyProfitLoss.new
                @init_unknown_pl.month = Date.new(2008,2)
                @init_unknown_pl.account_id = -1
                @init_unknown_pl.amount = 100
                @init_unknown_pl.user_id = users(:user1).id
                @init_unknown_pl.save!

                xhr :delete, :destroy, :id=>items(:adjustment2).id, :year => 2008, :month => 2
              end

              describe "response" do 
                subject { response }
                it { should be_success }
              end

              describe "specified item(adjustment2)" do
                subject { Item.find_by_id(@init_adj2.id) }
                it {should be_nil}
              end

              describe "adjustment4 which is next future adjustment" do
                subject { Item.find(@init_adj4.id) }
                its(:amount) { should == @init_adj4.amount + @init_adj2.amount }
              end

              describe "bank_pl amount" do
                subject { MonthlyProfitLoss.find(@init_bank_pl.id) }
                its(:amount) {should == @init_bank_pl.amount }
              end

              describe "unknown pl amount" do
                subject { MonthlyProfitLoss.find(@init_unknown_pl.id) }
                its(:amount) { should == @init_unknown_pl.amount}
              end
            end

            context "adj4を削除。影響をうけるのはadj6と,200802, 200803のm_pl" do 
              before do
                _login_and_change_month(2008,2)

                # データの初期化
                @init_adj2 = Item.find(items(:adjustment2).id)
                @init_adj4 = Item.find(items(:adjustment4).id)
                @init_adj6 = Item.find(items(:adjustment6).id)
                @init_bank_2_pl = monthly_profit_losses(:bank1200802)
                @init_bank_3_pl = monthly_profit_losses(:bank1200803)
                @init_unknown_2_pl = MonthlyProfitLoss.new
                @init_unknown_2_pl.month = Date.new(2008,2)
                @init_unknown_2_pl.account_id = -1
                @init_unknown_2_pl.amount = 100
                @init_unknown_2_pl.user_id = users(:user1).id
                @init_unknown_2_pl.save!
                @init_unknown_3_pl = MonthlyProfitLoss.new
                @init_unknown_3_pl.month = Date.new(2008,3)
                @init_unknown_3_pl.account_id = -1
                @init_unknown_3_pl.amount = 311
                @init_unknown_3_pl.user_id = users(:user1).id
                @init_unknown_3_pl.save!

                # 正常処理 (adj4を削除。影響をうけるのはadj6と,200802, 200803のm_pl)
                xhr :delete, :destroy, :id => items(:adjustment4).id, :year => 2008, :month => 2
              end

              describe "response" do
                subject { response }
                it { should be_success }
                its(:content_type) { should == "text/javascript" }
              end

              describe "previous adjustment(adj2)" do
                subject { Item.find_by_id(@init_adj2.id) }
                its(:amount) { should be == @init_adj2.amount }
              end

              describe "specified adjustment(adj4)" do
                subject { Item.find_by_id(@init_adj4.id) }
                it { should be_nil }
              end

              describe "next adjustment(adj6" do
                subject { Item.find_by_id(@init_adj6.id) }
                its(:amount) {should == @init_adj6.amount + @init_adj4.amount}
              end

              describe "bank_2_pl" do
                subject { MonthlyProfitLoss.find(@init_bank_2_pl.id) }
                its(:amount) { should == @init_bank_2_pl.amount - @init_adj4.amount}
              end

              describe "bank_3_pl" do
                subject { MonthlyProfitLoss.find(@init_bank_3_pl.id) }
                its(:amount) { should == @init_bank_3_pl.amount + @init_adj4.amount}
              end

              describe "unknown_2_pl" do
                subject { MonthlyProfitLoss.find(@init_unknown_2_pl.id)}
                its(:amount) { should == @init_unknown_2_pl.amount + @init_adj4.amount }
              end
              
              describe "unknown_3_pl" do
                subject { MonthlyProfitLoss.find(@init_unknown_3_pl.id)}
                its(:amount) { should == @init_unknown_3_pl.amount - @init_adj4.amount }
              end
            end

            context "adj6を削除(影響をうけるadjustmentは無い)" do
              before do
                _login_and_change_month(2008,3)

                # データの初期化
                @init_adj2 = Item.find(items(:adjustment2).id)
                @init_adj4 = Item.find(items(:adjustment4).id)
                @init_adj6 = Item.find(items(:adjustment6).id)
                @init_bank_2_pl = monthly_profit_losses(:bank1200802)
                @init_bank_3_pl = monthly_profit_losses(:bank1200803)
                @init_unknown_2_pl = MonthlyProfitLoss.new
                @init_unknown_2_pl.month = Date.new(2008,2)
                @init_unknown_2_pl.account_id = -1
                @init_unknown_2_pl.amount = 100
                @init_unknown_2_pl.user_id = users(:user1).id
                @init_unknown_2_pl.save!
                @init_unknown_3_pl = MonthlyProfitLoss.new
                @init_unknown_3_pl.month = Date.new(2008,3)
                @init_unknown_3_pl.account_id = -1
                @init_unknown_3_pl.amount = 311
                @init_unknown_3_pl.user_id = users(:user1).id
                @init_unknown_3_pl.save!

                xhr :delete, :destroy, :id => items(:adjustment6).id, :year => 2008, :month => 2
              end

              describe "response" do
                subject { response }
                it { should be_success }
                its(:content_type) { should == "text/javascript" }
              end

              describe "the adj before last adj(adj2)" do
                subject {Item.find_by_id(@init_adj2.id)}
                its(:amount) { should == @init_adj2.amount }
              end

              describe "the last adj(adj4)" do
                subject {Item.find_by_id(@init_adj4.id)}
                its(:amount) { should == @init_adj4.amount }
              end

              describe "specified adjustment(adj6)" do
                subject {Item.find_by_id(@init_adj6.id)}
                it { should be_nil }
              end

              describe "bank_2_pl" do
                subject { MonthlyProfitLoss.find(@init_bank_2_pl.id) }
                its(:amount) { should == @init_bank_2_pl.amount }
              end

              describe "bank_3_pl" do
                subject { MonthlyProfitLoss.find(@init_bank_3_pl.id) }
                its(:amount) { should == @init_bank_3_pl.amount - @init_adj6.amount }
              end

              describe "unknown_2" do
                subject { MonthlyProfitLoss.find(@init_unknown_2_pl.id) }
                its(:amount) { @init_unknown_2_pl.amount }
              end

              describe "unknown_3" do
                subject { MonthlyProfitLoss.find(@init_unknown_3_pl.id) }
                its(:amount) { @init_unknown_3_pl.amount + @init_adj6.amount }
              end
            end
          end
        end        
      end
    end
  end

  describe "#create" do
    context "before login," do
      before do
        xhr :post, :create
      end

      subject { response }
      it { should redirect_by_js_to login_url }
    end

    context "after login, " do
      before do
        login
      end
      
      context "when validation errors happen," do
        before do
          @previous_items = Item.count
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'', :amount=>'10,000', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :year => Date.today.year, :month => Date.today.month
        end

        describe "response" do 
          subject { response }
          it { should be_success }
          it { should render_rjs_error :id => 'warning', :default_message => _('Input value is incorrect') }
        end

        describe "the count of items" do
          subject { Item.count }
          it { should == @previous_items }
        end
      end

      shared_examples_for "created successfully" do
        describe "response" do 
          subject { response }
          it { should render_template "common/rjs_queue_renderer"}
        end

        describe "@renderer_queues" do
          subject { assigns(:renderer_queues) }
          it { should_not be_empty }
        end
      end

      context "when input amount's syntax is incorrect," do
        before do
          @previous_item_count = Item.count
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'hogehoge', :amount=>'1+x', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :year => Date.today.year, :month => Date.today.month
        end
        describe "response" do
          subject { response }
          it { should be_success }
          it { should render_rjs_error :id => "warning", :default_message => _("Amount is invalid.")}
        end

        describe "count of Item" do
          subject { Item.count }
          it { should == @previous_item_count }
        end
      end

      context "#create(only_add)" do
        before do 
#          login(true)
          @init_item_count = Item.count
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'test10', :amount=>'10,000', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :only_add=>'true'
        end

        it_should_behave_like "created successfully"

        describe "count of Item" do
          subject { Item.count }
          it { should == @init_item_count + 1 }
        end
      end

      shared_examples_for "created successfully with tag_list == 'hoge fuga" do
        describe "tags" do
          subject { Tag.find_all_by_name('hoge') }
          it { should have(1).tag }
          specify {
            subject.each do |t|
              taggings = Tagging.find_all_by_tag_id(t.id)
              assert_equal 1, taggings.size
              taggings.each do |tag|
                tag.user_id.should == users(:user1).id
                tag.taggable_type.should == 'Item'
              end
            end
          }
          
        end
      end

      context "with confirmation_required == true" do
        before do 
          @init_item_count = Item.count
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'テスト10', :amount=>'10,000', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :confirmation_required => 'true', :year => Date.today.year.to_s, :month => Date.today.month.to_s, :tag_list => 'hoge fuga'
        end

        it_should_behave_like "created successfully"

        describe "count of items" do
          subject { Item.count }
          it { should == @init_item_count + 1 }
        end

        describe "created item" do
          subject {
            id = Item.maximum('id')
            Item.find_by_id(id)
          }

          its(:name) { should == 'テスト10' }
          its(:amount) { should == 10000 }
          it { should be_confirmation_required }
          its(:tag_list) { should == "fuga hoge" }
        end

        it_should_behave_like "created successfully with tag_list == 'hoge fuga"
      end

      
      context "with confirmation_required == true" do
        before do 
          @init_item_count = Item.count
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'テスト10', :amount=>'10,000', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :confirmation_required => 'true', :year => Date.today.year.to_s, :month => Date.today.month.to_s, :tag_list => 'hoge fuga'
        end

        it_should_behave_like "created successfully"

        describe "count of items" do
          subject { Item.count }
          it { should == @init_item_count + 1 }
        end

        describe "created item" do
          subject {
            id = Item.maximum('id')
            Item.find_by_id(id)
          }

          its(:name) { should == 'テスト10' }
          its(:amount) { should == 10000 }
          it { should be_confirmation_required }
          its(:tag_list) { should == "fuga hoge" }
        end

        it_should_behave_like "created successfully with tag_list == 'hoge fuga"        
      end
      
      context "with confirmation_required == nil" do
        before do 
          @init_item_count = Item.count
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'テスト10', :amount=>'10,000', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :year => Date.today.year.to_s, :month => Date.today.month.to_s, :tag_list => 'hoge fuga'
        end

        it_should_behave_like "created successfully"

        describe "count of items" do
          subject { Item.count }
          it { should == @init_item_count + 1 }
        end

        describe "created item" do
          subject {
            id = Item.maximum('id')
            Item.find_by_id(id)
          }

          its(:name) { should == 'テスト10' }
          its(:amount) { should == 10000 }
          it { should_not be_confirmation_required }
          its(:tag_list) { should == "fuga hoge" }
        end

        it_should_behave_like "created successfully with tag_list == 'hoge fuga"        
      end

      context "when amount needs to be calcurated," do
        before do
          @init_item_count = Item.count
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'テスト10', :amount=>'(10 + 10)/40*20', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :confirmation_required => '', :year => Date.today.year, :month => Date.today.month
        end

        it_should_behave_like "created successfully"

        describe "count of items" do
          subject { Item.count}
          it { should == @init_item_count + 1 }
        end

        describe "new record" do
          subject { id = Item.maximum('id');  Item.find_by_id(id) }
          its(:amount) { should == 10 }
        end
      end
      
      context "when amount needs to be calcurated, but syntax error exists," do
        before do
          @init_item_count = Item.count
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'テスト10', :amount=>'(10+20*2.01', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :confirmation_required => '', :year => Date.today.year, :month => Date.today.month
        end

        describe "response" do
          subject { response }
          it { should render_rjs_error :id => "warning"}
        end
        
        describe "count of items" do
          subject { Item.count}
          it { should == @init_item_count }
        end
      end

      context "with invalid params when only_add = 'true'," do
        before do
          @init_item_count = Item.count
          login
          xhr :post, :create, :action_year=>Date.today.year.to_s, :action_month=>Date.today.month.to_s, :action_day=>Date.today.day.to_s,  :item_name=>'', :amount=>'10,000', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id, :only_add=>'true'
        end

        describe "response" do 
          subject { response }
          it { should be_success }
          it { should render_rjs_error :id => "warning" }
        end

        describe "count of items" do
          subject { Item.count }
          it { should == @init_item_count }
        end
      end

      context "with correct params," do
        before do
          @init_adj2 = Item.find(items(:adjustment2).id)
          @init_adj4 = Item.find(items(:adjustment4).id)
          @init_adj6 = Item.find(items(:adjustment6).id)
          @init_pl0712 = monthly_profit_losses(:bank1200712)
          @init_pl0801 = monthly_profit_losses(:bank1200801)
          @init_pl0802 = monthly_profit_losses(:bank1200802)
          @init_pl0803 = monthly_profit_losses(:bank1200803)
          _login_and_change_month(2008,2)
        end
        
        context "created before adjustment which is in the same month," do
          before do
            xhr(:post, :create,
                :action_year=>(@init_adj2.action_date - 1).year.to_s,
                :action_month=>(@init_adj2.action_date - 1).month.to_s,
                :action_day=>(@init_adj2.action_date - 1).day.to_s,
                :item_name=>'テスト10', :amount=>'10,000', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id,
                :year => 2008, :month => 2)
          end

          it_should_behave_like "created successfully"
          
          describe "adjustment just next to the created item" do
            subject { Item.find(items(:adjustment2).id) }
            its(:amount) { should == @init_adj2.amount + 10000 }
          end

          describe "adjustment which is the next of the adjustment next to the created item" do
            subject { Item.find(items(:adjustment4).id) }
            its(:amount) { should == @init_adj4.amount }
          end

          describe "adjustment which is the second next of the adjustment next to the created item" do
            subject { Item.find(items(:adjustment6).id)}
            its(:amount) { should == @init_adj6.amount }
          end

          describe "monthly pl which is before the created item" do
            subject { MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id) }
            its(:amount) { should == @init_pl0801.amount }
          end
          
          describe "monthly pl of the same month of the created item" do
            subject { MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id) }
            its(:amount) { should == @init_pl0802.amount }
          end
          
          describe "monthly pl of the next month of the created item" do
            subject { MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id) }
            its(:amount) { should == @init_pl0803.amount }
          end
        end

        context "created between adjustments which both are in the same month of the item to create," do
          before do
            @post = lambda {
              xhr(:post, :create,
                   :action_year=>(@init_adj4.action_date - 1).year.to_s,
                   :action_month=>(@init_adj4.action_date - 1).month.to_s,
                   :action_day=>(@init_adj4.action_date - 1).day.to_s,
                   :item_name=>'テスト10', :amount=>'10,000', :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id,
                  :year => 2008, :month => 2)
            }
          end
          
          describe "renderer" do 
            before do
              @post.call
            end
            it_should_behave_like "created successfully"
          end
          

          describe "adjustment which is before the created item" do
            specify { 
              expect { @post.call }.not_to change{ Item.find(@init_adj2.id).amount }
            }
          end

          describe "adjustment which is next to the created item in the same month" do
            specify { 
              expect { @post.call }.to change{ Item.find(@init_adj4.id).amount }.by(10000)
            }
          end

          describe "adjustment which is second next to the created item in the next month" do
            specify { 
              expect { @post.call }.not_to change{ Item.find(@init_adj6.id).amount }
            }
          end
          
          describe "the adjusted account's monthly_pl of the last month of the created item" do
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount
              }
            }
          end

          describe "the adjusted account's monthly_pl of the same month as that of the created item" do
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount
              }
            }
          end

          describe "the adjusted account's monthly_pl of the next month of the created item" do
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount
              }
            }
          end

          describe "the non-adjusted account's monthly_pl of the next month of the created item" do
            before do
              @post.call
            end
            subject { MonthlyProfitLoss.where(:account_id => accounts(:outgo3).id, :month => Date.new(2008,3,1)).first }
            it { should be_nil }
          end

          describe "the non-adjusted account's monthly_pl of the same month as the created item" do
            specify {
              expect { @post.call }.to change{ 
                MonthlyProfitLoss.where(:account_id => accounts(:outgo3).id, :month => Date.new(2008,2,1)).first.amount
              }.by(10000)
            }
          end
        end

        context "created between adjustments, and the one is on earlier date in the same month and the other is in the next month of the item to create," do
          # adj4とadj6の間(adj4と同じ月)
          before do
            @post = lambda {
              xhr(:post, :create,
                   :action_year=>(@init_adj4.action_date + 1).year.to_s,
                   :action_month=>(@init_adj4.action_date + 1).month.to_s,
                   :action_day=>(@init_adj4.action_date + 1).day.to_s,
                   :item_name=>'テスト10', :amount=>'10,000', :from => accounts(:bank1).id, :to => accounts(:outgo3).id,
                  :year => 2008, :month => 2)
            }
          end

          describe "renderer" do 
            before do
              @post.call
            end
            it_should_behave_like "created successfully"
          end

          describe "the adjustment of the month before the item" do
            specify {
              expect { @post.call }.not_to change{ Item.find(@init_adj2.id).amount }
            }
          end
          
          describe "the adjustments of the date before the item" do
            specify {
              expect { @post.call }.not_to change{ Item.find(@init_adj2.id).amount }
              expect { @post.call }.not_to change{ Item.find(@init_adj4.id).amount }
            }
          end

          describe "the adjustments of the next of item" do
            specify {
              expect { @post.call }.to change{ Item.find(@init_adj6.id).amount }.by(10000)
            }
          end

          describe "the adjusted account's monthly_pl of the last month of the created item" do
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount
              }
            }
          end

          describe "the adjusted account's monthly_pl of the same month as that of the created item" do
            specify {
              expect { @post.call }.to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount
              }.by(-10000)
            }
          end

          describe "the adjusted account's monthly_pl of the next month of the created item" do
            specify {
              expect { @post.call }.to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount
              }.by(10000)
            }
          end

          describe "the non-adjusted account's monthly_pl of the next month of the created item" do
            before do
              @post.call
            end
            subject { MonthlyProfitLoss.where(:account_id => accounts(:outgo3).id, :month => Date.new(2008,3,1)).first }
            it { should be_nil }
          end

          describe "the non-adjusted account's monthly_pl of the same month as the created item" do
            specify {
              expect { @post.call }.to change{ 
                MonthlyProfitLoss.where(:account_id => accounts(:outgo3).id, :month => Date.new(2008,2,1)).first.amount
              }.by(10000)
            }
          end
        end

        context "created between adjustments, and the one of next item's date is in the same month and the other is in the previous month of the item to create," do
          before do
            @post = lambda {
              xhr(:post, :create,
                   :action_year=>(@init_adj6.action_date - 1).year.to_s,
                   :action_month=>(@init_adj6.action_date - 1).month.to_s,
                   :action_day=>(@init_adj6.action_date - 1).day.to_s,
                   :item_name=>'テスト10', :amount=>'10,000', :from => accounts(:bank1).id, :to => accounts(:outgo3).id,
                  :year => 2008, :month => 2)
            }
          end

          describe "renderer" do 
            before do
              @post.call
            end
            it_should_behave_like "created successfully"
          end

          describe "the adjustment of the month before the item" do
            specify {
              expect { @post.call }.not_to change{ Item.find(@init_adj2.id).amount }
              expect { @post.call }.not_to change{ Item.find(@init_adj4.id).amount }
            }
          end
          
          describe "the adjustments of the next of item" do
            specify {
              expect { @post.call }.to change{ Item.find(@init_adj6.id).amount }.by(10000)
            }
          end


          describe "the adjusted account's monthly_pl of the last month or before of the created item" do
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount
              }
            }
            
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount
              }
            }
          end

          describe "the adjusted account's monthly_pl of the same month as that of the created item" do
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount
              }
            }
          end

          describe "the non-adjusted account's monthly_pl of the same month as the created item which does not exist before." do
            before do
              @post.call
            end
            subject { MonthlyProfitLoss.where(:account_id => accounts(:outgo3).id, :month => Date.new(2008,3,1)).first.amount }
            it { should == 10000 }
          end
        end

        context "created after any adjustments, and the one of last item's date is in the same month and the other is in the previous month of the item to create," do
          # after adj6
          before do
            @post = lambda {
              xhr(:post, :create,
                   :action_year=>(@init_adj6.action_date + 1).year.to_s,
                   :action_month=>(@init_adj6.action_date + 1).month.to_s,
                   :action_day=>(@init_adj6.action_date + 1).day.to_s,
                   :item_name=>'テスト10', :amount=>'10,000', :from => accounts(:bank1).id, :to => accounts(:outgo3).id,
                  :year => 2008, :month => 2)
            }
          end

          describe "renderer" do 
            before do
              @post.call
            end
            it_should_behave_like "created successfully"
          end

          describe "the adjustments before the item" do
            specify {
              expect { @post.call }.not_to change{ Item.find(@init_adj2.id).amount }
              expect { @post.call }.not_to change{ Item.find(@init_adj4.id).amount }
              expect { @post.call }.not_to change{ Item.find(@init_adj6.id).amount }
            }
          end
          
          describe "the adjusted account's monthly_pl of the last month or before of the created item" do
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount
              }
            }
            
            specify {
              expect { @post.call }.not_to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount
              }
            }
          end

          describe "the adjusted account's monthly_pl of the same month as that of the created item" do
            specify {
              expect { @post.call }.to change{ 
                MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount
              }.by(-10000)
            }
          end

          describe "the non-adjusted account's monthly_pl of the same month as the created item which does not exist before." do
            before do
              @post.call
            end
            subject { MonthlyProfitLoss.where(:account_id => accounts(:outgo3).id, :month => Date.new(2008,3,1)).first.amount }
            it { should == 10000 }
          end
        end
      end

      describe "credit card payment" do 
        context "created item with credit card, purchased before the settlement date of the month" do
          before do 
            _login_and_change_month(2008,2)
            xhr :post, :create,
            :action_year=>'2008',
            :action_month=>'2',
            :action_day=>'10',
            :item_name=>'テスト10', :amount=>'10,000', :from=>accounts(:credit4).id, :to=>accounts(:outgo3).id,
            :year => 2008, :month => 2
          end

          let(:credit_item) { Item.where(:action_date => Date.new(2008,2,10),
                                         :from_account_id => accounts(:credit4).id,
                                         :to_account_id => accounts(:outgo3).id,
                                         :amount => 10000,
                                         :parent_id => nil).where("child_id is not null").first }
          
          describe "response" do
            subject { response }
            it { should be_success }
            its(:content_type) { should == "text/javascript" }
          end

          describe "created credit item" do
            subject { credit_item }
            it { should_not be_nil }
            its(:amount) { should == 10000 }
            its(:parent_id) { should be_nil }
            its(:child_id) { should_not be_nil }
            its(:child_item) { should_not be_nil }
          end

          describe "child item's count" do
            subject { Item.where(:parent_id => credit_item.id) }
            its(:count) { should == 1 }
          end

          describe "child item" do
            subject { Item.where(:parent_id => credit_item.id, :child_id => nil).first }
            its(:child_id) { should be_nil }
            its(:parent_item) { should == credit_item }
            its(:action_date) { should == Date.new(2008, 2 + credit_relations(:cr1).payment_month,credit_relations(:cr1).payment_day) }
            its(:from_account_id) { should == credit_relations(:cr1).payment_account_id }
            its(:to_account_id) { should == credit_relations(:cr1).credit_account_id }
            its(:amount) { should == 10000 }
          end
        end
        
        context "created item with credit card, purchased before the settlement date of the month" do
          before do
            _login_and_change_month(2008,2)
            cr1 = credit_relations(:cr1)
            cr1.settlement_day = 15
            assert cr1.save
            
            xhr(:post, :create,
                :action_year=>'2008',
                :action_month=>'2',
                :action_day=>'25',
                :item_name=>'テスト10', :amount=>'10,000',
                :from=>accounts(:credit4).id, :to=>accounts(:outgo3).id,
                :year => 2008, :month => 2)
          end

          describe "response" do
            subject { response }
            it { should be_success }
            its(:content_type) { should == "text/javascript" }
          end

          let(:credit_item) {
            Item.where(:action_date => Date.new(2008,2,25),
                       :from_account_id => accounts(:credit4).id,
                       :to_account_id => accounts(:outgo3).id,
                       :amount => 10000, :parent_id => nil).where("child_id is not null").first
          }

          describe "created credit item" do
            subject { credit_item }
            it { should_not be_nil }
            its(:amount) { should == 10000 }
            its(:parent_id) { should be_nil }
            its(:child_id) { should_not be_nil }
            its(:action_date) { should == Date.new(2008,2,25)}
          end

          describe "child item" do
            describe "child item count" do
              subject { Item.where(:parent_id => credit_item.id) }
              its(:count) { should == 1 }
            end

            describe "child item" do
              subject { Item.where(:parent_id => credit_item.id).first }
              its(:child_id) { should be_nil }
              its(:parent_id) { should == credit_item.id }
              its(:id) { should == credit_item.child_id }
              its(:action_date) { should == Date.new(2008, 3 + credit_relations(:cr1).payment_month,credit_relations(:cr1).payment_day) }
              its(:from_account_id) { should == credit_relations(:cr1).payment_account_id }
              its(:to_account_id) { should == credit_relations(:cr1).credit_account_id }
              its(:amount) { should == 10000 }
            end
          end
        end

        context "created item with credit card, whose settlement_date == 99" do
          before do
            @cr1 = credit_relations(:cr1)
            @cr1.payment_day = 99
            assert @cr1.save
            _login_and_change_month(2008,2)
            
            xhr(:post, :create,
                :action_year=>'2008',
                :action_month=>'2',
                :action_day=>'10',
                :item_name=>'テスト10', :amount=>'10,000', :from=>accounts(:credit4).id, :to=>accounts(:outgo3).id,
                :year => 2008,
                :month => 2)
          end
          
          describe "response" do
            subject { response }
            it { should be_success }
            its(:content_type) { should == "text/javascript" }
          end

          let(:credit_item) {
            Item.where(:action_date => Date.new(2008,2,10),
                       :from_account_id => accounts(:credit4).id,
                       :to_account_id => accounts(:outgo3).id,
                       :amount => 10000, :parent_id => nil).where("child_id is not null").first
          }

          describe "created credit item" do
            subject { credit_item }
            it { should_not be_nil }
            its(:amount) { should == 10000 }
            its(:parent_id) { should be_nil }
            its(:child_id) { should_not be_nil }
            its(:action_date) { should == Date.new(2008,2,10)}
          end

          describe "child item's count" do
            subject { Item.where(:parent_id => credit_item.id) }
            its(:count) { should == 1 }
          end

          describe "child item" do
            subject { Item.where(:parent_id => credit_item.id).first }
            its(:child_id) { should be_nil }
            its(:parent_id) { should == credit_item.id }
            its(:id) { should == credit_item.child_id }
            its(:action_date) { should == Date.new(2008, 2 + @cr1.payment_month,1).end_of_month }
            its(:from_account_id) { should == @cr1.payment_account_id }
            its(:to_account_id) { should == @cr1.credit_account_id }
            its(:amount) { should == 10000 }
          end
        end
      end

      describe "balance adjustment" do
        context "action_year is not set," do
          specify {
            expect { xhr :post, :create, :action_month=>'2', :action_day=>'5', :from=>'-1', :to=>accounts(:bank1).id.to_s, :adjustment_amount=>'3000', :entry_type => 'adjustment', :year => 2008, :month => 2 }.not_to change { Item.count }
          }
        end

        context "with invalid calcuration amount," do

          specify {
            date = items(:adjustment2).action_date - 1
            expect {xhr :post,  :create, :entry_type => 'adjustment', :action_year=>date.year, :action_month=>date.month, :action_day=>date.day, :to=>accounts(:bank1).id.to_s, :adjustment_amount=>'3000-(10', :year => 2008, :month => 2}.not_to change { Item.count }
            
          }
        end
        
        context "add adjustment before any of the adjustments," do
          before do 
            _login_and_change_month(2008,2)
            @date = items(:adjustment2).action_date - 1
            @action = lambda {
              xhr(:post, :create, :entry_type => 'adjustment',
                  :action_year => @date.year, :action_month => @date.month, :action_day => @date.day,
                  :to => accounts(:bank1).id.to_s, :adjustment_amount=>'100*(10+50)/2', :year => 2008, :month => 2, :tag_list => 'hoge fuga')
            }
          end

          describe "count of Item" do
            specify {
              expect {@action.call}.to change { Item.count }.by(1)
            }
          end

          describe "created adjustment" do
            before do
              account_id = accounts(:bank1).id
              init_items = Item.where("action_date <= ?", @date )
              @init_total = init_items.where(:to_account_id => account_id).sum(:amount) - init_items.where(:from_account_id => account_id).sum(:amount)
              @action.call
              @created_item = Item.where(:user_id => users(:user1).id, :action_date => @date).order("id desc").first
              prev_items = Item.where("id < ?", @created_item.id).where("action_date <= ?", @date )
              @prev_total = prev_items.where(:to_account_id => account_id).sum(:amount) - prev_items.where(:from_account_id => account_id).sum(:amount)
            end
            subject { @created_item }

            it { should be_is_adjustment }
            its(:adjustment_amount) { should == 100*(10+50)/2 }
            its(:amount) { should == 100*(10+50)/2 - @prev_total }
            its(:amount) { should == 100*(10+50)/2 - @init_total }
            its(:tag_list) { should == "fuga hoge"}
          end

          describe "profit losses" do
            specify {
              expect { @action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id).amount }
            }
            
            specify {
              expect { @action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount }
            }

            specify {
              expect { @action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount }
            }

            specify {
              expect { @action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount }
            }
          end

          describe "tag" do
            specify {
              expect {@action.call}.to change{Tag.where(:name => 'hoge').count}.by(1)
            }
            
            specify {
              expect {@action.call}.to change{Tag.where(:name => 'fuga').count}.by(1)
            }
          end
          
          describe "taggings" do
            specify {
              expect {@action.call}.to change{Tagging.where(:user_id => users(:user1).id, :taggable_type => 'Item').count}.by(2)
            }
          end
        end

        context "create adjustment between adjustments whose months are same," do
          let(:date) { items(:adjustment4).action_date - 1 }
          let(:next_adj_date) { items(:adjustment4).action_date }
          let(:action) do
            lambda { xhr(:post,
                         :create, :entry_type => 'adjustment',
                         :action_year => date.year, :action_month => date.month, :action_day => date.day,
                         :to => accounts(:bank1).id.to_s, :adjustment_amount => '3000',
                         :year => 2008, :month => 2)
            }
          end
          
          before do
            @amount_before = total_amount_to(date)
            _login_and_change_month(2008,2)
          end

          describe "response" do
            before do
              action.call
            end
            subject { response }
            it { should be_success }
          end

          describe "count of items" do
            specify {
              expect { action.call }.to change{ Item.count }.by(1)
            }
          end
          
          describe "created adjustment" do
            before do
              action.call
              @created_adj = Item.where(:user_id => users(:user1).id, :action_date => date, :is_adjustment => true, :to_account_id => accounts(:bank1).id).first
            end
            subject { @created_adj }
            its(:adjustment_amount) { should == 3000 }
            its(:from_account_id) { should == -1 }
            its(:amount) { should == 3000 - @amount_before }
          end

          def total_amount_to(the_date)
            common_cond = Item.where("action_date <= ?", the_date).where(:user_id => users(:user1).id)
            common_cond.where(:to_account_id => accounts(:bank1).id).sum(:amount) - common_cond.where(:from_account_id => accounts(:bank1).id).sum(:amount)
          end
          
          describe "total of amounts to the date" do
            before do
              action.call
            end
            subject { total_amount_to(date) }
            it { should == 3000 }
          end

          describe "total of amounts to the date which has the next adjustment" do
            before do
              action.call
            end
            subject {  total_amount_to(next_adj_date) }
            it { should == items(:adjustment4).adjustment_amount }
          end
          
          describe "profit losses" do
            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id).amount }
            }
            
            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount }
            }

            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount }
            }

            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount }
            }
          end
        end

        context "create adjustment between adjustments whose months are different and created item is of the same month of earlier one," do
          let(:date) { items(:adjustment4).action_date + 1 }
          let(:next_adj_date) { items(:adjustment6).action_date }
          let(:action) do
            lambda { xhr(:post,
                         :create, :entry_type => 'adjustment',
                         :action_year => date.year, :action_month => date.month, :action_day => date.day,
                         :to => accounts(:bank1).id.to_s, :adjustment_amount => '3000',
                         :year => 2008, :month => 2)
            }
          end
          
          before do
            @amount_before = total_amount_to(date)
            _login_and_change_month(2008,2)
          end
          describe "response" do
            before do
              action.call
            end
            subject { response }
            it { should be_success }
          end

          describe "count of items" do
            specify {
              expect { action.call }.to change{ Item.count }.by(1)
            }
          end
          
          def total_amount_to(the_date)
            common_cond = Item.where("action_date <= ?", the_date).where(:user_id => users(:user1).id)
            common_cond.where(:to_account_id => accounts(:bank1).id).sum(:amount) - common_cond.where(:from_account_id => accounts(:bank1).id).sum(:amount)
          end
          
          describe "created adjustment" do
            before do
              action.call
              @created_adj = Item.where(:user_id => users(:user1).id, :action_date => date, :is_adjustment => true, :to_account_id => accounts(:bank1).id).first
            end
            subject { @created_adj }
            its(:adjustment_amount) { should == 3000 }
            its(:from_account_id) { should == -1 }
            its(:amount) { should == 3000 - @amount_before }
          end

          describe "next adjustment" do
            specify {
              expect { action.call }.to change { Item.find(items(:adjustment6).id).amount }.by(@amount_before - 3000)
            }
          end
          
          describe "total of amounts to the date" do
            before do
              action.call
            end
            subject { total_amount_to(date) }
            it { should == 3000 }
          end

          describe "total of amounts to the date which has the next adjustment" do
            before do
              action.call
            end
            subject {  total_amount_to(next_adj_date) }
            it { should == items(:adjustment6).adjustment_amount }
          end
          
          describe "profit losses" do
            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id).amount }
            }
            
            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount }
            }

            specify {
              expect { action.call }.to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount }.by(3000 - @amount_before)
            }

            specify {
              expect { action.call }.to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount }.by(@amount_before - 3000)
            }
          end
        end

        context "create adjustment between adjustments whose months are different and created item is of the same month of later one," do
          let(:date) { items(:adjustment6).action_date - 1 }
          let(:next_adj_date) { items(:adjustment6).action_date }
          let(:action) do
            lambda { xhr(:post,
                         :create, :entry_type => 'adjustment',
                         :action_year => date.year, :action_month => date.month, :action_day => date.day,
                         :to => accounts(:bank1).id.to_s, :adjustment_amount => '3000',
                         :year => 2008, :month => 2)
            }
          end
          
          before do
            @amount_before = total_amount_to(date)
            _login_and_change_month(2008,2)
          end
          describe "response" do
            before do
              action.call
            end
            subject { response }
            it { should be_success }
          end

          describe "count of items" do
            specify {
              expect { action.call }.to change{ Item.count }.by(1)
            }
          end
          
          def total_amount_to(the_date)
            common_cond = Item.where("action_date <= ?", the_date).where(:user_id => users(:user1).id)
            common_cond.where(:to_account_id => accounts(:bank1).id).sum(:amount) - common_cond.where(:from_account_id => accounts(:bank1).id).sum(:amount)
          end
          
          describe "created adjustment" do
            before do
              action.call
              @created_adj = Item.where(:user_id => users(:user1).id, :action_date => date, :is_adjustment => true, :to_account_id => accounts(:bank1).id).first
            end
            subject { @created_adj }
            its(:adjustment_amount) { should == 3000 }
            its(:from_account_id) { should == -1 }
            its(:amount) { should == 3000 - @amount_before }
          end

          describe "next adjustment" do
            specify {
              expect { action.call }.to change { Item.find(items(:adjustment6).id).amount }.by(@amount_before - 3000)
            }
          end
          
          describe "total of amounts to the date" do
            before do
              action.call
            end
            subject { total_amount_to(date) }
            it { should == 3000 }
          end

          describe "total of amounts to the date which has the next adjustment" do
            before do
              action.call
            end
            subject {  total_amount_to(next_adj_date) }
            it { should == items(:adjustment6).adjustment_amount }
          end
          
          describe "profit losses" do
            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id).amount }
            }
            
            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount }
            }

            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount }
            }

            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount }
            }
          end
        end

        context "create adjustment after all adjustments," do
          let(:date) { items(:adjustment6).action_date + 1 }
          let(:action) do
            lambda { xhr(:post,
                         :create, :entry_type => 'adjustment',
                         :action_year => date.year, :action_month => date.month, :action_day => date.day,
                         :to => accounts(:bank1).id.to_s, :adjustment_amount => '3000',
                         :year => 2008, :month => 2)
            }
          end
          
          before do
            @amount_before = total_amount_to(date)
            _login_and_change_month(2008,2)
          end
          describe "response" do
            before do
              action.call
            end
            subject { response }
            it { should be_success }
          end

          describe "count of items" do
            specify {
              expect { action.call }.to change{ Item.count }.by(1)
            }
          end
          
          def total_amount_to(the_date)
            common_cond = Item.where("action_date <= ?", the_date).where(:user_id => users(:user1).id)
            common_cond.where(:to_account_id => accounts(:bank1).id).sum(:amount) - common_cond.where(:from_account_id => accounts(:bank1).id).sum(:amount)
          end
          
          describe "created adjustment" do
            before do
              action.call
              @created_adj = Item.where(:user_id => users(:user1).id, :action_date => date, :is_adjustment => true, :to_account_id => accounts(:bank1).id).first
            end
            subject { @created_adj }
            its(:adjustment_amount) { should == 3000 }
            its(:from_account_id) { should == -1 }
            its(:amount) { should == 3000 - @amount_before }
          end

          describe "total of amounts to the date" do
            before do
              action.call
            end
            subject { total_amount_to(date) }
            it { should == 3000 }
          end

          describe "profit losses" do
            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id).amount }
            }
            
            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id).amount }
            }

            specify {
              expect { action.call }.not_to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount }
            }

            specify {
              expect { action.call }.to change{ MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount }.by(3000 - @amount_before)
            }
          end
        end
      end
    end
  end

  describe "#update" do
    context "before login," do 
      before do
        xhr :put, :update, :entry_type => 'adjustment', :year => Date.today.year, :month => Date.today.month
      end

      describe "response" do 
        subject {response}
        it { should redirect_by_js_to login_url }
      end
    end

    context "after login," do 
      before do
        _login_and_change_month(2008,2)
      end
      context "without id" do
        before do 
          date = items(:adjustment2).action_date
          xhr :put, :update, :entry_type => 'adjustment', :action_year=>date.year, :action_month=>date.month, :action_day=>date.day, :amount=>'3,000', :to=>items(:adjustment2).to_account_id, :year => 2008, :month => 2
        end
        
        describe "response" do 
          subject {response}
          it { should redirect_by_js_to login_url }
        end
      end
      

      describe "update adjustment" do
        context "without action date" do
          before do
            date = items(:adjustment2).action_date
            @action = lambda { xhr :put, :update, :entry_type => 'adjustment', :id=>items(:adjustment2).id.to_s, :action_year=>date.year, :action_month=>date.month, :action_amount=>'3,000', :to=>items(:adjustment2).to_account_id, :year => 2008, :month => 2 }
          end
          describe "response" do 
            before do
              @action.call
            end
            subject {response}
            it {should be_success}
          end

          describe "item to update" do
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment2).id).updated_at}

            }
          end
        end

        context "with invalid function for amount" do
          before do
            _login_and_change_month(2008,2)
            date = items(:adjustment2).action_date
            @action = lambda { xhr :put, :update, :entry_type => 'adjustment', :id=>items(:adjustment2).id, :action_year=>date.year, :action_month=>date.month, :action_day=>date.day, :adjustment_amount=>'(20*30)/(10+1', :to=>items(:adjustment2).to_account_id, :year => 2008, :month => 2 }
          end

          describe "response" do
            subject {response}
            it {should be_success}
          end

          describe "count of items" do
            specify {
              expect{@action.call}.not_to change{Item.count}
            }
          end
        end

        context "with changing only amount" do
          before do
            @old_adj2 = items(:adjustment2)
            @old_adj4 = items(:adjustment4)
            @old_adj6 = items(:adjustment6)
            @old_m_pl_bank1_200802 = monthly_profit_losses(:bank1200802)
            
            date = items(:adjustment2).action_date

            @action = lambda {xhr :put, :update, :entry_type => 'adjustment', :id=>items(:adjustment2).id, :action_year=>date.year, :action_month=>date.month, :action_day=>date.day, :adjustment_amount=>'(10+50)*200/4', :to=>items(:adjustment2).to_account_id, :year => 2008, :month => 2, :tag_list => 'hoge fuga'}
          end

          describe "response" do
            before do
              @action.call
            end
            subject {response}
            it {should be_success}
          end

          describe "updated item" do
            before do
              @action.call
            end
            subject {Item.find(@old_adj2.id)}
            its(:adjustment_amount) { should == 3000 }
            its(:action_date) { should == @old_adj2.action_date }
            it { should be_is_adjustment }
            its(:amount) {should == 3000 - @old_adj2.adjustment_amount + @old_adj2.amount}
            its(:tag_list) {should == 'fuga hoge'}
          end

          describe "the adjustment item next to the updated item" do
            before do
              @action.call
            end
            subject {Item.find(@old_adj4.id)}
            its(:amount) {should == @old_adj4.amount + @old_adj2.adjustment_amount - 3000 }
          end

          describe "the adjustment item second next to the updated item" do
            before do
              @action.call
            end
            subject {Item.find(@old_adj6.id)}
            its(:amount) {should == @old_adj6.amount }
          end

          describe "monthly pl" do
            specify {
              expect {@action.call}.not_to change{MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount}
            }
          end
        end

        context "when there is no future adjustment," do 
          before do 
            @old_adj6 = items(:adjustment6)
            date = items(:adjustment6).action_date
            @action = lambda { xhr :put, :update, :entry_type => 'adjustment', :id=>items(:adjustment6).id, :action_year=>date.year, :action_month=>date.month, :action_day=>date.day, :adjustment_amount => '3,000', :to => items(:adjustment6).to_account_id, :year => date.year, :month => date.month }
          end

          describe "response" do
            before { @action.call }
            subject {response}
            it {should be_success}
          end

          describe "updated item" do
            specify {
              expect{@action.call}.to change{Item.find(items(:adjustment6).id).updated_at}
            }
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment6).id).action_date}
            }
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment6).id).is_adjustment?}
            }
            specify {
              expect{@action.call}.to change{Item.find(items(:adjustment6).id).adjustment_amount}.to(3000)
            }
            specify {
              expect{@action.call}.to change{Item.find(items(:adjustment6).id).amount}.by(3000 - @old_adj6.adjustment_amount)
            }
          end

          describe "other adjustments" do
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment2).id).amount}
            }
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment4).id).amount}
            }
          end

          describe "monthly pl" do
            specify {
              expect{@action.call}.to change{MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount}.by(3000 - @old_adj6.adjustment_amount)
            }
          end
        end

        #
        # 日付に変更がなく、未来のadjが存在するが、当月ではない場合
        #
        context "when change amount the adjustment which has an adjustment in the next month" do 
          before do
            @old_adj4 = items(:adjustment4)
            date = @old_adj4.action_date
            # 金額のみ変更
            @action = lambda { xhr :put, :update, :entry_type => 'adjustment',
              :id => @old_adj4.id,
              :action_year => date.year, :action_month => date.month, :action_day => date.day,
              :adjustment_amount => '3,000', :to => @old_adj4.to_account_id,
              :year => date.year, :month => date.month }
          end

          describe "response" do
            before {@action.call}
            subject {response}
            it {should be_success}
          end

          describe "updated item" do
            specify {
              expect{@action.call}.to change{Item.find(items(:adjustment4).id).updated_at}
            }
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment4).id).action_date}
            }
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment4).id).is_adjustment?}
            }
            specify {
              expect{@action.call}.to change{Item.find(items(:adjustment4).id).adjustment_amount}.to(3000)
            }
            specify {
              expect{@action.call}.to change{Item.find(items(:adjustment4).id).amount}.by(3000 - @old_adj4.adjustment_amount)
            }
          end

          describe "other adjustments" do
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment2).id).amount}
            }
            specify {
              expect{@action.call}.to change{Item.find(items(:adjustment6).id).amount}.by(@old_adj4.adjustment_amount - 3000)
            }
          end

          describe "monthly pl" do
            specify {
              expect{@action.call}.to change{MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount}.by(3000 - @old_adj4.adjustment_amount)
            }
            specify {
              expect{@action.call}.to change{MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount}.by(@old_adj4.adjustment_amount - 3000)
            }
          end
        end
      
        context "when change to_account_id and date," do
          before do
            @init_adj2 = items(:adjustment2)
            @date = date = items(:adjustment4).action_date - 1
            
            @action = lambda { xhr :put, :update, :entry_type => 'adjustment',
              :id => items(:adjustment2).id,
              :action_year => date.year, :action_month => date.month, :action_day => date.day,
              :adjustment_amount => '3,000', :to => items(:adjustment2).to_account_id,
              :year => date.year, :month => date.month}
          end

          describe "response" do
            before do
              @action.call
            end
            subject {response}
            it {should be_success}
          end

          describe "updated item" do
            def item
              Item.find(items(:adjustment2).id)
            end
            specify {
              expect{@action.call}.to change{item.adjustment_amount}.to(3000)
            }
            specify {
              expect{@action.call}.to change{item.action_date}.to(@date)
            }
            specify {
              expect{@action.call}.not_to change{item.is_adjustment?}
            }
            specify {
              expect{@action.call}.to change{item.amount}.by(3000 - @init_adj2.adjustment_amount)
            }
          end

          describe "other adjustment items" do
            specify {
              expect{@action.call}.to change{Item.find(items(:adjustment4).id).amount}.by(@init_adj2.adjustment_amount - 3000)
            }
            specify {
              expect{@action.call}.not_to change{Item.find(items(:adjustment6).id).amount}
            }
          end

          describe "monthly pls" do
            specify {
              expect{@action.call}.not_to change{MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount}
              expect{@action.call}.not_to change{MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount}
            }
            
          end
        end
        
        pending("#update for adjustment specに未変換")
        it "test_update_adjustment_change_account_id" do
          old_adj2 = items(:adjustment2)
          old_adj4 = items(:adjustment4)
          old_adj6 = items(:adjustment6)
          old_m_pl_bank1_200802 = monthly_profit_losses(:bank1200802)
          old_m_pl_bank1_200803 = monthly_profit_losses(:bank1200803)

          xhr :post, :create, :entry_type => 'adjustment', :action_year=>old_adj4.action_date.year, :action_month=>old_adj4.action_date.month, :action_day=>old_adj4.action_date.day, :to=>13,:adjustment_amount => '1000', :year=>old_adj4.action_date.year, :month=>old_adj4.action_date.month
          old_adj_other = Item.find(:first, :conditions=>["action_date = ? and to_account_id = 13 and is_adjustment = ?", old_adj4.action_date, true])
          assert_not_nil old_adj_other
          date = old_adj2.action_date

          xhr :put, :update, :entry_type => 'adjustment', :id=>items(:adjustment2).id, :action_year=>date.year, :action_month=>date.month, :action_day=>date.day, :adjustment_amount=>'3,000', :to=>old_adj_other.to_account_id, :year => date.year, :month => date.month

          assert_select_rjs :replace_html, "items", ''
          assert_select_rjs :insert_html, :bottom, 'items'
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' + date.strftime("%Y/%m/%d") + ' ' + 'Adjustment' + ' ' +
            CommonUtil.separate_by_comma(3000) + 'yen'
        end

        it "test_update_adjustment_change_date_to_next_month" do
          # 日付、金額を変更
          old_adj2 = items(:adjustment2)
          old_adj4 = items(:adjustment4)
          old_adj6 = items(:adjustment6)
          old_m_pl_bank1_200802 = monthly_profit_losses(:bank1200802)
          old_m_pl_bank1_200803 = monthly_profit_losses(:bank1200803)


          date = items(:adjustment6).action_date - 1

          xhr :put, :update, :entry_type => 'adjustment', :id=>items(:adjustment2).id, :action_year=>date.year, :action_month=>date.month, :action_day=>date.day, :adjustment_amount=>'3,000', :to=>items(:adjustment2).to_account_id, :year => date.year, :month => date.month
          assert_select_rjs :replace_html, :items, ''
          assert_select_rjs :insert_html, :bottom, :items
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' + date.strftime("%Y/%m/%d") + ' ' + 'Adjustment' + ' ' +
            CommonUtil.separate_by_comma(3000) + 'yen'

          new_adj2 = Item.find(items(:adjustment2).id)
          assert_equal 3000, new_adj2.adjustment_amount
          assert_equal old_adj6.action_date - 1, new_adj2.action_date
          assert new_adj2.is_adjustment?

          assert_equal new_adj2.adjustment_amount - (13900 - 22000), new_adj2.amount
          assert_equal old_adj4.amount + old_adj2.amount, Item.find(items(:adjustment4).id).amount
          assert_equal old_adj6.amount - new_adj2.amount, Item.find(items(:adjustment6).id).amount
          assert_equal old_m_pl_bank1_200802.amount, MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount
          assert_equal old_m_pl_bank1_200803.amount, MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount
        end

        it "test_update_adjustment_change_date_to_next_month_no_future_adj" do 
          # 日付、金額を変更
          old_adj2 = items(:adjustment2)
          old_adj4 = items(:adjustment4)
          old_adj6 = items(:adjustment6)
          old_m_pl_bank1_200802 = monthly_profit_losses(:bank1200802)
          old_m_pl_bank1_200803 = monthly_profit_losses(:bank1200803)

          login

          date = items(:adjustment6).action_date + 1

          xhr :put, :update, :entry_type => 'adjustment', :id=>items(:adjustment2).id, :action_year=>date.year, :action_month=>date.month, :action_day=>date.day, :adjustment_amount=>'3,000', :to=>items(:adjustment2).to_account_id, :year => date.year, :month => date.month
          assert_select_rjs :replace_html, :items, ''
          assert_select_rjs :insert_html, :bottom, :items
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' + date.strftime("%Y/%m/%d") + ' ' + 'Adjustment' + ' ' +
            CommonUtil.separate_by_comma(3000) + 'yen'

          new_adj2 = Item.find(items(:adjustment2).id)
          assert_equal 3000, new_adj2.adjustment_amount
          assert_equal old_adj6.action_date + 1, new_adj2.action_date
          assert new_adj2.is_adjustment?

          assert_equal new_adj2.adjustment_amount - (12900 - 22000), new_adj2.amount
          assert_equal old_adj4.amount + old_adj2.amount, Item.find(items(:adjustment4).id).amount
          assert_equal old_adj6.amount, Item.find(items(:adjustment6).id).amount
          assert_equal old_m_pl_bank1_200802.amount, MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id).amount
          assert_equal old_m_pl_bank1_200803.amount + new_adj2.amount, MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id).amount
        end
      end

      describe "update item" do

        context "with missing id," do
          before do
            # id is missing
            xhr :put, :update, :year => 2008, :month => 2
          end
          
          describe "response" do 
            subject {response}
            it { should redirect_by_js_to login_url }
          end
        end

        context "with missing params" do
          before do
            @action = lambda {xhr :put, :update, :id=>items(:item1).id, :year => 2008, :month => 2}
          end

          describe "item to update" do
            specify {
              expect {@action.call}.not_to change{Item.find(items(:item1).id).updated_at}
            }
          end
        end

        context "with invalid amount function, " do
          before do 
            @old_item1 = old_item1 = items(:item1)
            @action = lambda {
              xhr(:put, :update,
                  :id => old_item1.id,
                  :item_name => 'テスト10',
                  :action_year => old_item1.action_date.year,
                  :action_month => old_item1.action_date.month,
                  :action_day => '18',
                  :amount => "(100-20)*(10",
                  :from => accounts(:bank1).id,
                  :to => accounts(:outgo3).id,
                  :confirmation_required => 'true',
                  :year => 2008, :month => 2)
              }
          end
          
          describe "response" do
            before {@action.call}
            subject {response}
            it {should be_success}
          end

          describe "item to update" do
            def item
              Item.find(@old_item1.id)
            end
            specify {
              expect {@action.call}.not_to change{item.updated_at}
            }
            specify {
              expect {@action.call}.not_to change{item.name}
            }
            specify {
              expect {@action.call}.not_to change{item.action_date}
            }
            specify {
              expect {@action.call}.not_to change{item.amount}
            }
          end
        end
        
        context "without changing date, " do
          before do
            @old_item11 = items(:item11)
            xhr(:put, :update, :id => @old_item11.id,
                :item_name =>'テスト11',
                :action_year => @old_item11.action_date.year,
                :action_month => @old_item11.action_date.month,
                :action_day => @old_item11.action_date.day,
                :amount => "100000",
                :from => accounts(:bank1).id, :to => accounts(:outgo3).id,
                :year => 2008, :month => 2)
          end

          describe "response" do
            subject {response}
            it {should be_success}
          end

          describe "updated item" do
            subject {Item.find(@old_item11.id)}
            its(:name) {should == 'テスト11'}
            its(:action_date) {should == @old_item11.action_date}
            its(:amount) {should == 100000}
            its(:from_account_id) {should == accounts(:bank1).id}
            its(:to_account_id) {should == accounts(:outgo3).id}
          end
        end

        context "with amount being function," do
          before do
            @old_item1 = old_item1 = items(:item1)
            @date = old_item1.action_date + 65
            xhr(:put, :update,
                :id => items(:item1).id,
                :item_name => 'テスト10000',
                :action_year => @date.year,
                :action_month => @date.month,
                :action_day => @date.day,
                :amount=>"(100-20)*1.007",
                :from=>accounts(:bank1).id, :to=>accounts(:outgo3).id,
                :confirmation_required => 'true', :year => 2008, :month => 2)
          end
          
          describe "response" do
            subject {response}
            it {should be_success}
          end

          describe "updated item" do
            subject {Item.find(@old_item1.id)}
            its(:name) {should == 'テスト10000'}
            its(:action_date) {should == @date}
            its(:amount) {should == (80*1.007).to_i }
            its(:from_account_id) {should == accounts(:bank1).id}
            its(:to_account_id) {should == accounts(:outgo3).id}
            it {should be_confirmation_required}
          end

        end

        
        pending("#update for item specに未変換")
        it "test_update_item" do

          old_item1 = items(:item1)
          old_item11 = items(:item11)
          old_adj2 = items(:adjustment2)
          old_adj4 = items(:adjustment4)
          old_adj6 = items(:adjustment6)
          old_pl200712 = monthly_profit_losses(:bank1200712)
          old_pl200801 = monthly_profit_losses(:bank1200801)
          old_pl200802 = monthly_profit_losses(:bank1200802)
          old_pl200803 = monthly_profit_losses(:bank1200803)
          old_pl200712_out = monthly_profit_losses(:outgo3200712)
          old_pl200801_out = monthly_profit_losses(:outgo3200801)
          old_pl200802_out = monthly_profit_losses(:outgo3200802)
          #old_pl200803_out = monthly_profit_losses(:outgo3200803)  # nil 存在しない
          old_pl200803_out = nil

          today = Date.today

          # regular (action_date's month is not changed and future and same month's adjustment exists)
          xhr :put, :update, :id=>items(:item1).id, :item_name=>'テスト10', :action_year=>old_item1.action_date.year.to_s, :action_month=>old_item1.action_date.month.to_s, :action_day=>'18', :amount=>"100000", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :year => 2008, :month => 2
          assert_select_rjs :replace_html, :items, ''
          assert_select_rjs :insert_html, :bottom, :items
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' + Date.new(old_item1.action_date.year,old_item1.action_date.month,18).strftime("%Y/%m/%d") + ' ' + 'テスト10' + ' ' + CommonUtil.separate_by_comma(100000) + 'yen'
          #assert_select_rjs :visual_effect, :highlight, 'item_' + items(:item1).id.to_s, :duration=>'1.0'

          # データの整合性チェック
          new1_item1 = Item.find(items(:item1).id)
          new1_adj2 = Item.find(items(:adjustment2).id)
          new1_adj4 = Item.find(items(:adjustment4).id)
          new1_adj6 = Item.find(items(:adjustment6).id)
          new1_pl200712 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id)
          new1_pl200801 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id)
          new1_pl200802 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id)
          new1_pl200803 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id)
          new1_pl200712_out = MonthlyProfitLoss.find(monthly_profit_losses(:outgo3200712).id)
          new1_pl200801_out = MonthlyProfitLoss.find(monthly_profit_losses(:outgo3200801).id)
          new1_pl200802_out = MonthlyProfitLoss.find(monthly_profit_losses(:outgo3200802).id)
          new1_pl200803_out = MonthlyProfitLoss.find(:first,
                                                     :conditions=>["user_id = ? and account_id = ? and month = ?",
                                                                   users(:user1).id, accounts(:outgo3).id,
                                                                   Date.new(2008,3,1)])  # nil 存在しないはず


          assert_equal 'テスト10', new1_item1.name
          assert_equal Date.new(old_item1.action_date.year,old_item1.action_date.month,18), new1_item1.action_date
          assert_equal 100000, new1_item1.amount
          assert_equal accounts(:bank1).id, new1_item1.from_account_id
          assert_equal accounts(:outgo3).id, new1_item1.to_account_id
          assert (not new1_item1.confirmation_required?)

          assert_equal old_adj2.amount - old_item1.amount + new1_item1.amount, new1_adj2.amount
          assert_equal old_adj4.amount, new1_adj4.amount
          assert_equal old_adj6.amount, new1_adj6.amount
          assert_equal old_pl200712.amount, new1_pl200712.amount
          assert_equal old_pl200801.amount, new1_pl200801.amount
          assert_equal old_pl200802.amount, new1_pl200802.amount
          assert_equal old_pl200803.amount, new1_pl200803.amount
          assert_equal old_pl200712_out.amount, new1_pl200712_out.amount
          assert_equal old_pl200801_out.amount, new1_pl200801_out.amount
          assert_equal old_pl200802_out.amount - old_item1.amount + new1_item1.amount, new1_pl200802_out.amount
          assert_nil new1_pl200803_out


          # regular (confirmation_required == true)
          xhr :put, :update, :id=>items(:item1).id, :item_name=>'テスト10', :action_year=>old_item1.action_date.year.to_s, :action_month=>old_item1.action_date.month.to_s, :action_day=>'18', :amount=>"100000", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :confirmation_required => 'true', :year => 2008, :month => 2
          item_confirm_required = Item.find_by_id(items(:item1).id)
          assert item_confirm_required.confirmation_required?

          # regular (タグにゅうりょく)
          xhr :put, :update, :id=>items(:item1).id, :item_name=>'テスト10', :action_year=>old_item1.action_date.year.to_s, :action_month=>old_item1.action_date.month.to_s, :action_day=>'18', :amount=>"100000", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :confirmation_required => 'true', :tag_list => 'hoge fuga', :year => 2008, :month => 2
          item_confirm_required = Item.find_by_id(items(:item1).id)
          assert item_confirm_required.confirmation_required?
          assert_equal 'hoge fuga'.split(" ").sort.join(" "), item_confirm_required.tag_list
          tags = Tag.find_all_by_name('hoge')
          assert_equal 1, tags.size
          tags.each do |t|
            taggings = Tagging.find_all_by_tag_id(t.id)
            assert_equal 1, taggings.size
            taggings.each do |tgg|
              assert_equal users(:user1).id, tgg.user_id
              assert_equal 'Item', tgg.taggable_type
            end
          end
        end
        
        # regular (action_date's month is not changed, but day is changed from before-adj to after-adj
        # and future-same month's adjustment DOES NOT exists)
        it "test_update_item_from_before_adj2_to_after_adj4" do

          new1_item1 = items(:item1)
          new1_adj2 = items(:adjustment2)
          new1_adj4 = items(:adjustment4)
          new1_adj6 = items(:adjustment6)
          new1_pl200712 = monthly_profit_losses(:bank1200712)
          new1_pl200801 = monthly_profit_losses(:bank1200801)
          new1_pl200802 = monthly_profit_losses(:bank1200802)
          new1_pl200803 = monthly_profit_losses(:bank1200803)
          date = new1_adj4.action_date + 1
          xhr :put, :update, :id=>items(:item1).id, :item_name=>'テスト20', :action_year=>date.year.to_s, :action_month=>date.month.to_s, :action_day=>date.day.to_s, :amount=>"20000", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :year => items(:item1).action_date.year, :month => items(:item1).action_date.month

#          assert_no_rjs :replace_html, :account_status
#          assert_no_rjs :replace_html, :confirmation_status, Regexp.new(confirmation_status_path)
          assert_select_rjs :replace_html, :items, ''
          assert_select_rjs :insert_html, :bottom, :items  # remains_list
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' +  Date.new(date.year,date.month,date.day).strftime("%Y/%m/%d") + ' ' + 'テスト20' + ' ' + CommonUtil.separate_by_comma(20000) + 'yen'
          #   assert_select_rjs :visual_effect, :highlight, 'item_' + items(:item1).id.to_s, :duration=>'1.0'

          # データの整合性チェック
          new2_item1 = Item.find(items(:item1).id)
          new2_adj2 = Item.find(items(:adjustment2).id)
          new2_adj4 = Item.find(items(:adjustment4).id)
          new2_adj6 = Item.find(items(:adjustment6).id)
          new2_pl200712 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id)
          new2_pl200801 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id)
          new2_pl200802 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id)
          new2_pl200803 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id)

          assert_equal 'テスト20', new2_item1.name
          assert_equal Date.new(date.year,date.month,date.day), new2_item1.action_date
          assert_equal 20000, new2_item1.amount
          assert_equal accounts(:bank1).id, new2_item1.from_account_id
          assert_equal accounts(:outgo3).id, new2_item1.to_account_id

          assert_equal new1_adj2.amount - new1_item1.amount, new2_adj2.amount
          assert_equal new1_adj4.amount, new2_adj4.amount
          assert_equal new1_adj6.amount + new2_item1.amount, new2_adj6.amount  # this is the different month

          assert_equal new1_pl200712.amount, new2_pl200712.amount
          assert_equal new1_pl200801.amount, new2_pl200801.amount
          assert_equal new1_pl200802.amount - new2_item1.amount, new2_pl200802.amount
          assert_equal new1_pl200803.amount + new2_item1.amount , new2_pl200803.amount
        end

        # regular (action_date's month, day are not changed
        # and future-same month's adjustment DOES NOT exists)
        it "test_update_item_after_adj4_same_month" do

          old_item5 = Item.find(items(:item5).id)
          new2_item1 = Item.find(items(:item1).id)
          new2_adj2 = Item.find(items(:adjustment2).id)
          new2_adj4 = Item.find(items(:adjustment4).id)
          new2_adj6 = Item.find(items(:adjustment6).id)
          new2_pl200712 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id)
          new2_pl200801 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id)
          new2_pl200802 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id)
          new2_pl200803 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id)

          xhr :put, :update, :id=>items(:item5).id, :item_name=>'テスト30', :action_year=>old_item5.action_date.year.to_s, :action_month=>old_item5.action_date.month.to_s, :action_day=>old_item5.action_date.day.to_s, :amount=>"20000", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :year => 2008, :month => 2

          #    assert_no_rjs :replace_html, :account_status
          #    assert_no_rjs :replace_html, :confirmation_status
          assert_select_rjs :replace, 'item_' + items(:item5).id.to_s
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' + old_item5.action_date.strftime("%Y/%m/%d") + ' ' + 'テスト30' + ' ' + CommonUtil.separate_by_comma(20000) + 'yen'
          #   assert_select_rjs :visual_effect, :highlight, 'item_' + items(:item5).id.to_s, :duration=>'1.0'


          # データの整合性チェック
          new3_item1 = Item.find(items(:item1).id)
          new3_adj2 = Item.find(items(:adjustment2).id)
          new3_adj4 = Item.find(items(:adjustment4).id)
          new3_item5 = Item.find(items(:item5).id)
          new3_adj6 = Item.find(items(:adjustment6).id)
          new3_pl200712 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id)
          new3_pl200801 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id)
          new3_pl200802 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id)
          new3_pl200803 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id)

          assert_equal 'テスト30', new3_item5.name
          assert_equal old_item5.action_date, new3_item5.action_date
          assert_equal 20000, new3_item5.amount
          assert_equal accounts(:bank1).id, new3_item5.from_account_id
          assert_equal accounts(:outgo3).id, new3_item1.to_account_id

          assert_equal new2_adj2.amount, new3_adj2.amount
          assert_equal new2_adj4.amount, new3_adj4.amount
          assert_equal new2_adj6.amount - old_item5.amount + new3_item5.amount, new3_adj6.amount
          assert_equal new2_pl200712.amount, new3_pl200712.amount
          assert_equal new2_pl200801.amount, new3_pl200801.amount
          assert_equal new2_pl200802.amount + old_item5.amount - new3_item5.amount, new3_pl200802.amount
          assert_equal new2_pl200803.amount - old_item5.amount + new3_item5.amount, new3_pl200803.amount
        end

        # adj2 adj4の間にあるitemを変更し adj6の手前に日付にする(金額も変更)
        it "test_update_item_from_adj2_adj4_to_before_adj6" do
          new3_item3 = items(:item3)
          new3_item1 = items(:item1)
          new3_adj2 = items(:adjustment2)
          new3_adj4 = items(:adjustment4)
          new3_item5 = items(:item5)
          new3_adj6 = items(:adjustment6)
          new3_pl200712 = monthly_profit_losses(:bank1200712)
          new3_pl200801 = monthly_profit_losses(:bank1200801)
          new3_pl200802 = monthly_profit_losses(:bank1200802)
          new3_pl200803 = monthly_profit_losses(:bank1200803)

          date = new3_adj6.action_date - 1
          xhr :put, :update, :id=>items(:item3).id, :item_name=>'テスト50', :action_year=>date.year.to_s, :action_month=>date.month.to_s, :action_day=>date.day.to_s, :amount=>"300", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :year => items(:item3).action_date.year, :month => items(:item3).action_date.month


#          assert_no_rjs :replace_html, :account_status
#          assert_no_rjs :replace_html, :confirmation_status
          assert_select_rjs :replace_html, :items, ''
          assert_select_rjs :insert_html, :bottom, :items  # remains_list
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' +  Date.new(date.year,date.month,date.day).strftime("%Y/%m/%d") + ' ' + 'テスト50' + ' ' + CommonUtil.separate_by_comma(300) + 'yen'

          # データの整合性チェック
          new4_item3 = Item.find(items(:item3).id)
          new4_adj2 = Item.find(items(:adjustment2).id)
          new4_adj4 = Item.find(items(:adjustment4).id)
          new4_adj6 = Item.find(items(:adjustment6).id)
          new4_pl200712 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id)
          new4_pl200801 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id)
          new4_pl200802 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id)
          new4_pl200803 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id)

          assert_equal 'テスト50', new4_item3.name
          assert_equal Date.new(date.year,date.month,date.day), new4_item3.action_date
          assert_equal 300, new4_item3.amount
          assert_equal accounts(:bank1).id, new4_item3.from_account_id
          assert_equal accounts(:outgo3).id, new4_item3.to_account_id

          assert_equal new3_adj2.amount, new4_adj2.amount
          assert_equal new3_adj4.amount - new3_item3.amount, new4_adj4.amount
          assert_equal new3_adj6.amount + new4_item3.amount, new4_adj6.amount

          assert_equal new3_pl200712.amount, new4_pl200712.amount
          assert_equal new3_pl200801.amount, new4_pl200801.amount
          assert_equal new3_pl200802.amount, new4_pl200802.amount
          assert_equal new3_pl200803.amount, new4_pl200803.amount
        end

        # item1をadj6(次月のadjのうしろ)に移動(価格を変更)
        it "test_update_item_from_before_adj2_to_after_adj6" do

          new3_item1 = items(:item1)
          new3_adj2 = items(:adjustment2)
          new3_adj4 = items(:adjustment4)
          new3_item5 = items(:item5)
          new3_adj6 = items(:adjustment6)
          new3_pl200712 = monthly_profit_losses(:bank1200712)
          new3_pl200801 = monthly_profit_losses(:bank1200801)
          new3_pl200802 = monthly_profit_losses(:bank1200802)
          new3_pl200803 = monthly_profit_losses(:bank1200803)

          date = new3_adj6.action_date + 1
          xhr :put, :update, :id=>items(:item1).id, :item_name=>'テスト50', :action_year=>date.year.to_s, :action_month=>date.month.to_s, :action_day=>date.day.to_s, :amount=>"300", :from=>accounts(:bank1).id.to_s, :to=>accounts(:outgo3).id.to_s, :year => items(:item1).action_date.year, :month => items(:item1).action_date.month


#          assert_no_rjs :replace_html, :account_status
#          assert_no_rjs :replace_html, :confirmation_status
          assert_select_rjs :replace_html, :items, ''
          assert_select_rjs :insert_html, :bottom, :items  # remains_list
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' +  Date.new(date.year,date.month,date.day).strftime("%Y/%m/%d") + ' ' + 'テスト50' + ' ' + CommonUtil.separate_by_comma(300) + 'yen'
          #   assert_select_rjs :visual_effect, :highlight, 'item_' + items(:item1).id.to_s, :duration=>'1.0'

          # データの整合性チェック
          new4_item1 = Item.find(items(:item1).id)
          new4_adj2 = Item.find(items(:adjustment2).id)
          new4_adj4 = Item.find(items(:adjustment4).id)
          new4_adj6 = Item.find(items(:adjustment6).id)
          new4_pl200712 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200712).id)
          new4_pl200801 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200801).id)
          new4_pl200802 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200802).id)
          new4_pl200803 = MonthlyProfitLoss.find(monthly_profit_losses(:bank1200803).id)

          assert_equal 'テスト50', new4_item1.name
          assert_equal Date.new(date.year,date.month,date.day), new4_item1.action_date
          assert_equal 300, new4_item1.amount
          assert_equal accounts(:bank1).id, new4_item1.from_account_id
          assert_equal accounts(:outgo3).id, new4_item1.to_account_id

          assert_equal new3_adj2.amount - new3_item1.amount, new4_adj2.amount
          assert_equal new3_adj4.amount, new4_adj4.amount
          assert_equal new3_adj6.amount, new4_adj6.amount

          assert_equal new3_pl200712.amount, new4_pl200712.amount
          assert_equal new3_pl200801.amount, new4_pl200801.amount
          assert_equal new3_pl200802.amount, new4_pl200802.amount
          assert_equal new3_pl200803.amount - new4_item1.amount , new4_pl200803.amount
        end

        ###############################
        # クレジットカードの変更処理
        ###############################
        def test_update_item_credit_item
          # 前処理
          _login_and_change_month(2008,2)
          xhr :post, :create, :action_year=>'2008', :action_month=>'2', :action_day=>'10', :item_name=>'テスト10', :amount=>'10,000', :from=>accounts(:credit4).id, :to=>accounts(:outgo3).id,
          :year => 2008,
          :month => 2
          
          init_credit_item = Item.find(:first, :conditions=>["action_date = ? and from_account_id = ? and to_account_id = ?",
                                                             Date.new(2008,2,10),
                                                             accounts(:credit4).id,
                                                             accounts(:outgo3).id])
          assert_not_nil init_credit_item
          init_payment_item = Item.find(init_credit_item.child_id)
          date = init_credit_item.action_date
          assert_equal 10000, init_credit_item.amount
          
          xhr :put, :update, :id=>init_credit_item.id, :item_name=>'テスト10', :action_year=>date.year.to_s, :action_month=>date.month.to_s, :action_day=>date.day.to_s, :amount=>"20000", :from=>accounts(:credit4).id.to_s, :to=>accounts(:outgo3).id.to_s, :year => init_credit_item.action_date.year, :month => init_credit_item.action_date.month

          new_credit_item = Item.find(init_credit_item.id)
          new_payment_item = Item.find(new_credit_item.child_id)
          assert_no_rjs :replace_html, :account_status
          assert_no_rjs :replace_html, :confirmation_status
          assert_select_rjs :replace, 'item_' + init_credit_item.id.to_s
          assert_select_rjs :replace_html, :warning, 'Item was changed successfully.' + ' ' + init_credit_item.action_date.strftime("%Y/%m/%d") + ' ' + 'テスト10' + ' ' + CommonUtil.separate_by_comma(20000) + 'yen'
          assert_no_rjs :replace_html, 'item_' + init_payment_item.id.to_s
          assert_no_rjs :replace_html, 'item_' + new_payment_item.id.to_s
          assert_equal 20000, new_credit_item.amount
          assert_not_equal new_payment_item.id, init_payment_item.id
          assert_equal 20000, new_payment_item.amount
        end
      end
    end
  end
end
