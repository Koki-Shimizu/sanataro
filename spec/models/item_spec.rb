# -*- coding: utf-8 -*-
require 'spec_helper'

describe Item do
  fixtures :items, :users, :accounts, :monthly_profit_losses
  before do 
    @valid_attrs = {
      :user_id => users(:user1).id,
      :name => 'aaaa',
      :year => 2008,
      :month => 10,
      :day => 17,
      :from_account_id => 1,
      :to_account_id => 2,
      :amount => 10000,
      :confirmation_required => true,
      :tag_list => 'hoge fuga'
    }
  end


  describe "create successfully" do
    before do
      @item = Item.new(@valid_attrs)
      @is_saved = @item.save!
      @saved_item = Item.find(@item.id)
    end
    
    describe "saved status" do
      subject { @is_saved }
      it { should be_true }
    end

    describe "created item's attributes" do
      subject { @saved_item }
      its(:action_date) { should == Date.new(2008,10,17) }
      its(:is_adjustment?) { should be_false }
      its(:confirmation_required?) { should be_true }
    end
  end
    
  describe "validation" do
    before do
      @item = Item.new(@valid_attrs)
    end

    describe "name" do 
      context "when name is nil" do
        before do
          @item.name = nil
          @is_saved = @item.save
        end

        describe "item was not saved" do
          subject { @is_saved }
          it { should be_false }
        end

        describe "error" do
          subject { @item }
          it { should have_at_least(1).errors_on :name }
        end
      end
    end

    describe "amount" do 
      context "when amount is nil" do
        before do
          @item.amount = nil
          @is_saved = @item.save
        end

        describe "item was not saved" do
          subject { @is_saved }
          it { should be_false }
        end

        describe "error" do
          subject { @item }
          it { should have_at_least(1).errors_on :amount }
        end
      end
      
    end

    describe "account_id" do 
      context "when from_account_id is nil" do
        before do
          @item.from_account_id = nil
          @is_saved = @item.save
        end

        describe "item was not saved" do
          subject { @is_saved }
          it { should be_false }
        end

        describe "error" do
          subject { @item }
          it { should have_at_least(1).errors_on :from_account_id }
        end
      end

      context "when to_account_id is nil" do
        before do
          @item.to_account_id = nil
          @is_saved = @item.save
        end

        describe "item was not saved" do
          subject { @is_saved }
          it { should be_false }
        end

        describe "error" do
          subject { @item }
          it { should have_at_least(1).errors_on :to_account_id }
        end
      end
    end

    describe "action_date" do
      context "when action_date is invalid" do
        before do
          @item.month = 2
          @item.day = 30
          @is_saved = @item.save
        end

        describe "item was not saved" do
          subject { @is_saved }
          it { should be_false }
        end

        describe "error" do
          subject { @item }
          it { should have_at_least(1).errors_on :action_date }
        end
      end

      context "when action_date is too past value" do
        before do
          @item.year = 2005
          @item.month = 2
          @item.day = 10
          @is_saved = @item.save
        end

        describe "item was not saved" do
          subject { @is_saved }
          it { should be_false }
        end

        describe "error" do
          subject { @item }
          it { should have_at_least(1).errors_on :action_date }
        end
      end

      context "when action_date is too future value" do
        before do
          future = 2.years.since(Time.now)
          @item.year = future.year
          @item.month = future.month
          @item.day = future.day
          @is_saved = @item.save
        end

        describe "item was not saved" do
          subject { @is_saved }
          it { should be_false }
        end

        describe "error" do
          subject { @item }
          it { should have_at_least(1).errors_on :action_date }
        end
      end
    end
    
  end

  describe "action_date calcuration" do
    before do
      @item = Item.find(1)
    end
    
    describe "getting from DB" do
      subject { @item }
      its(:year) { should be 2008 }
      its(:month) { should be 2 }
      its(:day) { should be 15 }
    end

    context "when nil is set to year" do
      before do
        @item.year = nil
      end
      subject { @item }
      its(:year) { should be_nil }
      its(:month) { should be_nil }
      its(:day) { should be_nil }
      its(:action_date) { should be_nil }
    end

    context "when nil is set to month" do
      before do
        @item.month = nil
      end
      subject { @item }
      its(:year) { should be_nil }
      its(:month) { should be_nil }
      its(:day) { should be_nil }
      its(:action_date) { should be_nil }
    end
    
    context "when nil is set to day" do
      before do
        @item.day = nil
      end
      subject { @item }
      its(:year) { should be_nil }
      its(:month) { should be_nil }
      its(:day) { should be_nil }
      its(:action_date) { should be_nil }
    end

    context "when Date object is set to action_date" do
      before do
        @item.action_date = Date.new(2010, 3, 10)
      end
      subject { @item }
      its(:year) { should be 2010 }
      its(:month) { should be 3 }
      its(:day) { should be 10 }
      its(:action_date) { should == Date.new(2010, 3, 10) }
    end
  end


  describe "adjustment" do
    #
    # 日付の順番は以下のとおり
    # item1 -> adj2 -> item3 -> adj4
    #
    before do
      @item1 = Item.find(1)
      @adj2 = Item.find(2)
      @item3 = Item.find(3)
      @adj4 = Item.find(4)
      @plbank1 = monthly_profit_losses(:bank1200802)
    end
    
    context "item1の金額を+100した時(item_idを指定)" do
      before do
        User.find(@item1.user_id).items.adjust_future_balance(User.find(@item1.user_id), @item1.from_account_id, 100, @item1.action_date, @item1.id)
      end

      describe "adj2" do
        subject { Item.find(2)}
        its(:amount) {should be(@adj2.amount + 100) }
        its(:adjustment_amount) {should be(@adj2.adjustment_amount) }
      end

      describe "item3" do
        subject { Item.find(3)}
        its(:amount) {should be(@item3.amount) }
      end

      describe "adj4" do
        subject { Item.find(4)}
        its(:amount) {should be(@adj4.amount) }
        its(:adjustment_amount) {should be(@adj4.adjustment_amount) }
      end

      describe "profit_losses of bank1" do
        subject { MonthlyProfitLoss.find(@plbank1.id) }
        its(:amount) { should be(@plbank1.amount + 100) }
      end
    end

    
    context "item1の金額を+100した時(item_idを指定しない)" do
      before do
        User.find(@item1.user_id).items.adjust_future_balance(User.find(@item1.user_id), @item1.from_account_id, 100, @item1.action_date)
      end

      describe "adj2" do
        subject { Item.find(2)}
        its(:amount) {should be(@adj2.amount + 100) }
      end

      describe "item3" do
        subject { Item.find(3)}
        its(:amount) {should be(@item3.amount) }
      end

      describe "adj4" do
        subject { Item.find(4)}
        its(:amount) {should be(@adj4.amount) }
      end

      describe "profit_losses of bank1" do
        subject { MonthlyProfitLoss.find(@plbank1.id) }
        its(:amount) { should be(@plbank1.amount + 100) }
      end
    end
    

    context "item3の金額を+100した時" do
      before do
        User.find(@item3.user_id).items.adjust_future_balance(User.find(@item3.user_id), @item3.from_account_id, 100, @item3.action_date, @item3.id)
      end

      describe "adj2" do
        subject {Item.find(@adj2.id)}
        its(:amount) { should be @adj2.amount}
        its(:adjustment_amount) { should be @adj2.adjustment_amount }
      end

      describe "adj4" do
        subject {Item.find(@adj4.id)}
        its(:amount) { should be @adj4.amount + 100}
        its(:adjustment_amount) { should be @adj4.adjustment_amount }
      end

      describe "Monthly Profit Loss of bank1" do
        subject { MonthlyProfitLoss.find(@plbank1.id) }
        its(:amount) { should be @plbank1.amount + 100 }
      end
    end

    context "adjustment2のitemとaction_dateが同一のitemを追加した場合" do
      context "when item3の金額を+100した場合" do
        before do
          item = Item.create!(:id => 105,
                              :user_id => users(:user1).id,
                              :name => 'aaaaa',
                              :year => @adj2.action_date.year,
                              :month => @adj2.action_date.month,
                              :day => @adj2.action_date.day,
                              :from_account_id => 1,
                              :to_account_id => 2,
                              :amount => 10000)
          
          User.find(item.user_id).items.adjust_future_balance(User.find(item.user_id), item.from_account_id, 10000, item.action_date, item.id)
        end

        describe "adj2" do
          subject { Item.find(@adj2.id) }
          its(:amount) { should be @adj2.amount}
          its(:adjustment_amount) { should be @adj2.adjustment_amount}
        end

        describe "adj4" do
          subject { Item.find(@adj4.id)}
          its(:amount) { should be @adj4.amount + 10000}
          its(:adjustment_amount) { should be @adj4.adjustment_amount}
        end

        describe "monthly profit loss of bank1" do
          subject { MonthlyProfitLoss.find(@plbank1.id) }
          its(:amount) { should be @plbank1.amount + 10000 }
        end
      end
    end

    context "item5を変更する(adj6(翌月のadjustment item)に影響がでる。同時にmonthly_profit_lossも翌月に変更が加わる)" do
      before do 
        @adj6 = items(:adjustment6)
        @plbank1_03 = monthly_profit_losses(:bank1200803)
        item = Item.create(:id => 105,
                           :user_id => users(:user1).id,
                           :name => 'aaaaa',
                           :year => @adj6.action_date.year,
                           :month => @adj6.action_date.month,
                           :day => @adj6.action_date.day - 1,
                           :from_account_id => 1,
                           :to_account_id => 2,
                           :amount => 200)
        Item.adjust_future_balance(User.find(item.user_id), item.from_account_id, 200, item.action_date, item.id)
      end

      describe "adj2" do
        subject { Item.find(2)}
        its(:amount) { should be @adj2.amount}
        its(:adjustment_amount) { should be @adj2.adjustment_amount}
      end

      describe "adj4" do 
        subject { Item.find(4)}
        its(:amount) { should be @adj4.amount}
        its(:adjustment_amount) { should be @adj4.adjustment_amount}
      end
      
      describe "adj6" do
        subject { Item.find(@adj6.id)}
        its(:amount) { should be @adj6.amount + 200}
        its(:adjustment_amount) { should be @adj6.adjustment_amount}
      end


      describe "MonthlyProfitLoss for bank1 in 2008/2" do
        subject { MonthlyProfitLoss.find(@plbank1.id) }
        its(:amount) { should be @plbank1.amount}
      end
      
      describe "MonthlyProfitLoss for bank1 in 2008/3" do
        subject { MonthlyProfitLoss.find(@plbank1_03.id) }
        its(:amount) { should be @plbank1_03.amount + 200}
      end
    end
  end


  describe "partial_items" do
    context "when entries are so many" do 
      before(:all) do
        @created_ids = []
        # データの準備
        Item.transaction do 
          50.times do 
            item = Fabricate.build(:item, from_account_id: 11, to_account_id: 13, action_date: '2008-09-15', tag_list: 'abc def', confirmation_required: true)
            item.save!
            @created_ids << item.id
          end
 
          # データの準備
          50.times do |i|
            item = Fabricate.build(:item, from_account_id: 21, to_account_id: 13, action_date: '2008-09-15', tag_list: 'ghi jkl')
            item.save!
            @created_ids << item.id
          end

          # データの準備(参照されないデータ)
          10.times do |i|
            item = Fabricate.build(:item, from_account_id: 11, to_account_id: 13, action_date: '2008-10-01', tag_list: 'mno pqr')
            item.save!
            @created_ids << item.id
          end

          # データの準備(参照されないデータ)(別ユーザ)
          80.times do |i|
            item = Fabricate.build(:item, user_id: 101, from_account_id: 11, to_account_id: 13, action_date: '2008-09-15', tag_list: 'abc def', confirmation_required: true)
            item.save!
            @created_ids << item.id
          end
        end
        
        @from_date = Date.new(2008,9,1)
        @to_date = Date.new(2008,9,30)
      end

      after(:all) do
        Item.transaction do 
          Item.destroy(@created_ids)
        end
      end
     
      context "when :remain is not specified" do
        subject { Item.find_partial(users(:user1),@from_date, @to_date) }
        it { should have(ITEM_LIST_COUNT).entries }
      end

      context "when :remain is specified as true" do
        subject { Item.find_partial(users(:user1), @from_date, @to_date, {:remain=>true}) }
        it { should have(100 - ITEM_LIST_COUNT).entries }
      end

      context "when :tag is specified" do
        subject { Item.find_partial(users(:user1),nil, nil, {:tag => 'abc' }) }
        it { should have(ITEM_LIST_COUNT).entries }
      end

      context "when :tag and :remain is specified" do
        subject { Item.find_partial(users(:user1),nil, nil, {:remain => true, :tag => 'abc' }) }
        it { should have(50 - ITEM_LIST_COUNT).entries }
      end

      context "when :filter_account_id is specified" do
        subject { Item.find_partial(users(:user1),@from_date, @to_date, {:filter_account_id => accounts(:bank11).id}) }
        it { should have(ITEM_LIST_COUNT).entries }
      end

      context "when :filter_account_id and :remain is specified" do
        subject { Item.find_partial(users(:user1),@from_date, @to_date, {:filter_account_id => accounts(:bank11).id, :remain => true}) }
        it { should have(50 - ITEM_LIST_COUNT).entries }
      end

      context "when confirmation required is specified"  do
        context "when remain not specified" do
          subject { Item.find_partial(users(:user1),nil, nil, {:mark => 'confirmation_required' }) }
          it { should have(ITEM_LIST_COUNT).entries }
        end
        
        context "when remain not specified" do
          before do 
            @cnfmt_rqrd_count = Item.where(:confirmation_required => true, :user_id => users(:user1).id).count
          end
          
          subject { Item.find_partial(users(:user1),nil, nil, {:mark => 'confirmation_required', :remain => true }) }
          it { should have(@cnfmt_rqrd_count - ITEM_LIST_COUNT).entries }
        end
        
      end
    end
    
    context "when entries are not so many" do 
      before(:all) do
        @created_ids = []
        # データの準備
        Item.transaction do 
          15.times do |i|
            @created_ids << Item.create!(:name => 'regular item ' + i.to_s,
                                         :user_id => 1,
                                         :from_account_id => 11,
                                         :to_account_id => 13,
                                         :action_date => Date.new(2008,9,15),
                                         :tag_list => 'abc def',
                                         :confirmation_required => true,
                                         :amount => 100 + i).id
          end

          # データの準備
          3.times do |i|
            @created_ids << Item.create!(:name => 'regular item ' + i.to_s,
                                         :user_id => 1,
                                         :from_account_id => 21,
                                         :to_account_id => 13,
                                         :action_date => Date.new(2008,9,15),
                                         :tag_list => 'ghi jkl',
                                         :amount => 100 + i).id
          end

          # データの準備(参照されないデータ)
          10.times do |i|
            @created_ids << Item.create!(:name => 'regular item ' + i.to_s,
                                         :user_id => 1,
                                         :from_account_id => 11,
                                         :to_account_id => 13,
                                         :action_date => Date.new(2008,10,1), # 参照されない日付
                                         :tag_list => 'mno pqr',
                                         :amount => 100 + i).id
          end

          # データの準備(参照されないデータ)(別ユーザ)
          80.times do |i|
            @created_ids << Item.create!(:name => 'regular item ' + i.to_s,
                                         :user_id => 101,
                                         :from_account_id => 11,
                                         :to_account_id => 13,
                                         :action_date => Date.new(2008,9,15),
                                         :amount => 100 + i).id
          end
          
        end
        @from_date = Date.new(2008,9,1)
        @to_date = Date.new(2008,9,30)
        
      end

      after(:all) do
        Item.transaction do 
          Item.destroy(@created_ids)
        end
      end

      context "when :remain is not specified" do
        subject { Item.find_partial(users(:user1), @from_date, @to_date) }
        it { should have(18).entries }
      end

      context "when :remain is true" do 
        subject { Item.find_partial(users(:user1), @from_date, @to_date, {'remain'=>true}) }
        it { should have(0).entries }
      end
      
      context "when :filter_account_id is specified" do 
        subject { Item.find_partial(users(:user1), @from_date, @to_date, {:filter_account_id=>accounts(:bank11).id}) }
        it { should have(15).entries }
      end
        
      context "when :filter_account_id and :remain is specified" do 
        subject { Item.find_partial(users(:user1), @from_date, @to_date, {:filter_account_id=>accounts(:bank11).id, :remain => true}) }
        it { should have(0).entries }
      end
    end
  end
  
  describe "collect_account_history" do
    describe "amount" do
      before do
        @amount, @items = Item.collect_account_history(users(:user1), accounts(:bank1).id, Date.new(2008,2,1), Date.new(2008,2,29))
      end
      
      describe "amount" do 
        subject { @amount }
        it { should be 8000 }
      end

      describe "items" do 
        subject {@items}
        specify {
          subject.each do |item|
            (item.from_account_id == accounts(:bank1).id ||  item.to_account_id == accounts(:bank1).id).should be_true
            item.action_date.should be_between Date.new(2008,2,1), Date.new(2008,2,29)
          end
        }
      end
    end
  end

  describe "user" do
    subject { Item.find(items(:item1).id) }

    its(:user) { should_not be_nil }
    specify { subject.user.id.should be subject.user_id }
  end

  describe "child_item" do
    before do 
      p_it = Item.new
      p_it.user = users(:user1)
      p_it.name = 'p hogehoge'
      p_it.from_account_id = 1
      p_it.to_account_id = 2
      p_it.amount = 500
      p_it.action_date = Date.new(2008,2,10)

      c_it = Item.new
      c_it.user = users(:user1)
      c_it.name = 'c hogehoge'
      c_it.from_account_id = 3
      c_it.to_account_id = 1
      c_it.amount = 500
      c_it.parent_id = p_it.id
      c_it.action_date = Date.new(2008,3,10)

      p_it.child_item = c_it
      p_it.save!

      @p_id = p_it.id
      @c_id = c_it.id
    end
    
    describe "parent_item" do
      subject { Item.find(@p_id) }
      it { should_not be_nil }
    end

    describe "child_item" do
      subject { Item.find(@c_id) }
      it { should_not be_nil }
    end
  end

  describe "confirmation_required" do
    context "parent_idのないitemでupdate_confirmation_requiredを呼びだすとき" do
      before do 
        @item = items(:item1)
        @item.update_confirmation_required_of_self_or_parent(false)        
      end

      subject { Item.find(@item.id) }
      it { should_not be_confirmation_required }
    end

    context "parent_idが存在するitemでupdate_confirmation_requiredを呼びだすとき" do
      before do
        @child_item = items(:credit_refill31)
        @child_item.update_confirmation_required_of_self_or_parent(true)
      end

      describe "child_item(self)" do
        subject { Item.find(@child_item.id) }
        it { should_not be_confirmation_required }
      end
      
      describe "parent_item" do
        subject { Item.find(@child_item.parent_id) }
        it { should be_confirmation_required }
      end
    end
  end

  describe "#to_custom_hash" do
    before do
      @valid_attrs = {
        user_id: users(:user1).id,
        name: 'aaaa',
        year: 2008,
        month: 10,
        day: 17,
        from_account_id: 1,
        to_account_id: 2,
        amount: 10000,
        confirmation_required: true,
        tag_list: 'hoge fuga',
        child_id: 100,
        parent_id: 200
      }

      @item = Item.create!(@valid_attrs)
      # acts_as_taggable plugin has a bug. After creating, #tags returns empty array.
      @item.reload
    end

    describe "item.to_custom_hash" do 
      subject { @item.to_custom_hash }
      it { should be_an_instance_of(Hash)}
      its([:entry]) { should be_an_instance_of(Hash)}
    end

    describe "item.to_custom_hash[:entry]" do
      subject { @item.to_custom_hash[:entry] }
      its([:id]) { should == @item.id }
      its([:name]) { should == "aaaa" }
      its([:action_date]) { should == Date.new(2008,10,17) }
      its([:from_account_id]) { should == 1 }
      its([:to_account_id]) { should == 2 }
      its([:amount]) { should == 10000 }
      its([:confirmation_required]) { should be_true }
      its([:tags]) { should == ['fuga', 'hoge'] }
      its([:child_id]) { should == 100 }
      its([:parent_id]) { should == 200 }
    end
  end

  describe "items.to_custom_hash" do
    describe "Array#to_custom_hash" do
      before do
        @items = Item.where(:user_id => users(:user1).id).all 
      end
      subject { @items.to_custom_hash }
      it { should be_an_instance_of(Array)}
      its([0]) { should == @items[0].to_custom_hash }
    end
  end

  describe "#year, #month, #day" do
    context "when p_year, p_month, p_day is set," do
      before do
        @item = Item.new
        @item.p_year = 2000
        @item.p_month = 1
        @item.p_day = 3
      end
      subject {@item}
      its(:year) {should == 2000}
      its(:month) {should == 1}
      its(:day) {should == 3}
    end

    context "when action_date is set," do
      before do
        @item = Item.new
        @item.action_date = Date.today
      end
      subject {@item}
      its(:year) {should == Date.today.year}
      its(:month) {should == Date.today.month}
      its(:day) {should == Date.today.day}
    end

    context "when neither action_date nor p_* are set," do
      before do
        @item = Item.new
      end
      subject {@item}
      its(:year) {should be_nil }
      its(:month) {should be_nil }
      its(:day) {should be_nil }
    end

    context "when both action_date and p_* are set," do
      before do
        @item = Item.new
        @item.action_date = Date.today
        @item.year = 2000
        @item.month = 10
        @item.day = 20
      end
      subject {@item}
      its(:year) {should == 2000 }
      its(:month) {should == 10 }
      its(:day) {should == 20 }
    end
  end
end
