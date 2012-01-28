# -*- coding: utf-8 -*-
class EntriesController < ApplicationController
  before_filter :required_login
  before_filter :set_separated_accounts, :only => [:index, :create, :update, :destroy, :new, :edit, :show]
  before_filter :_redirect_to_login_by_rjs_if_id_is_blank, :only => [:update]
  
  def index
    @tag = params[:tag]
    @mark = params[:mark]

    @display_year_month = _date_to_display(params[:year], params[:month])

    case
    when params[:remaining]
      _index_for_remaining(params[:year].to_i, params[:month].to_i, @tag, @mark)
    when !params[:filter_account_id].nil?
      _index_with_filter_account_id
    when @tag.present?
      _index_with_tag(@tag)
    when @mark.present?
      _index_with_mark(@mark)
    else
      _index_plain(@display_year_month)
    end
  rescue # 日付が不正の場合がある
    respond_to do |format|
      format.js {  redirect_rjs_to current_entries_url }
      format.html {  redirect_to current_entries_url }
    end
  end
  
  def _index_with_filter_account_id
    _set_filter_account_id_to_session_from_params
    @items = _get_items(@display_year_month.year, @display_year_month.month)
    render "index_with_filter_account_id"
  end
  
  def _index_with_tag(tag)
    @items = _get_items(nil, nil, false, tag, nil)
    render ('index_with_tag')
  end
  
  def _index_with_mark(mark)
    @items = _get_items(nil, nil, false, nil, mark)
    render ('index_with_mark')
  end
  
  def _default_action_date(month_to_display)
    month_to_display == today.beginning_of_month ? today : month_to_display
  end
  
  def _set_filter_account_id_to_session_from_params
    account_id = params[:filter_account_id].to_i
    session[:filter_account_id] = account_id == 0 ? nil : account_id
  end
      
  def _date_to_display(year, month)
    year.present? && month.present? ? Date.new(year.to_i, month.to_i) : today.beginning_of_month
  end
    
  
  def _index_plain(month_to_display)
    @items = _get_items(month_to_display.year, month_to_display.month)
    @new_item = Item.new { |item| item.action_date = _default_action_date(month_to_display) }
  end

  #
  # 支出、収入の登録入力
  #
  def new
    case params[:entry_type]
    when 'simple'
      _new_simple
    when 'adjustment'
      _new_adjustment
    else
      _new_entry
    end
  end
  
  def create
    if params[:entry_type] == 'adjustment'
      _create_adjustment
    else
      _create_entry
    end
  end
  
  def update
    if params[:entry_type] == 'adjustment'
      _update_adjustment
    else
      _update_item
    end

  end

  def _redirect_to_login_by_rjs_if_id_is_blank
    if params[:id].blank?
      redirect_rjs_to login_url
      return false
    end
    return true
  end
  
  def destroy
    item = @user.items.find(params[:id])
    _destroy_item(item)
  rescue ActiveRecord::RecordNotFound => ex
    url = params[:id].blank? ? login_url : entries_url(today.year, today.month)
    redirect_rjs_to url
  end

  def _destroy_item(item)
    if item.is_adjustment?
      _destroy_adjustment(item)
    else
      _destroy_regular_item(item)
    end
  end
  #
  # アイテムの編集領域の表示
  #
  def edit
    @item = @user.items.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    redirect_rjs_to entries_url(:year => today.year, :month => today.month)
  end
  
  #
  # replace an input field with a regular text
  #
  def show
    @item = @user.items.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    redirect_rjs_to current_entries_url
  end


  private

  # this method is called when a link in the field of adding adjustment
  # which switches to the regular item new entry input.
  def _new_entry
    item = Item.new
    if params[:year].blank? || params[:month].blank? || today.beginning_of_month == Date.new(params[:year].to_i, params[:month].to_i)
      item.action_date = today
    else
      item.action_date = Date.new(params[:year].to_i, params[:month].to_i)
    end

    @item = item
    render "add_item"
  end

  # this method is called when a link in the field of adding regular item
  # which switches to the adjustment item new entry input.
  def _new_adjustment
    @action_date = _get_date_by_specific_year_and_month_or_today(params[:year], params[:month])
    render "add_adjustment"
  end
  
  def _get_date_by_specific_year_and_month_or_today(year, month)
    action_date = nil
    begin
      unless today.beginning_of_month == Date.new(year.to_i, month.to_i).beginning_of_month
        action_date = Date.new(year.to_i, month.to_i)
      end
    rescue ArgumentError => ex
    end
    action_date || today
  end
  
  def _create_adjustment
    display_year = params[:year].to_i
    display_month = params[:month].to_i
    @display_year_month = Date.new(display_year, display_month)
    
    year, month, day = _get_action_year_month_day_from_params
    action_date = Date.new(year,month,day)
    
    to_account_id = CommonUtil.remove_comma(params[:to]).to_i
    adjustment_amount = Item.calc_amount(params[:adjustment_amount])
    
    Item.transaction do
      prev_adj = @user.items.find_by_to_account_id_and_action_date_and_is_adjustment(to_account_id, action_date, true)
      _do_delete_item(prev_adj.id) if prev_adj
      
      item, updated_items =
        Teller.create_entry(user: @user, action_date: action_date, name: 'Adjustment',
                            from_account_id: -1, to_account_id: to_account_id,
                            is_adjustment: true, tag_list: params[:tag_list],
                            adjustment_amount: adjustment_amount)

      items = _get_items(item.action_date.year, item.action_date.month)
      updated_items << item
      
      render "create_adjustment", locals: { item: item, items: items, updated_items: updated_items.reject(&:nil?) }
    end
  rescue SyntaxError
    render_rjs_error :id => "warning", :default_message => _("Amount is invalid.")
  rescue InvalidDate
    render_rjs_error :id => "warning", :default_message => "日付が不正です。"
  rescue ActiveRecord::RecordInvalid => ex
    render_rjs_error(:id => "warning", :errors => ex.message.split(",").map(&:strip), :default_message => _('Input value is incorrect'))
  end

  #
  # exec adding item.
  #
  def _create_entry
    Item.transaction do
      year, month, day = _get_action_year_month_day_from_params
      name  = params[:item_name]
      only_add = params[:only_add]
      from  = params[:from].to_i
      to  = params[:to].to_i
      confirmation_required = params[:confirmation_required]
      tag_list = params[:tag_list]
      unless only_add
        display_year = params[:year].to_i
        display_month = params[:month].to_i
        @display_year_month = Date.new(display_year, display_month)
      end
      # could raise SyntaxError because of :amount has an statement.
      amount = Item.calc_amount(params[:amount])

      item, affected_items =
        Teller.create_entry(:user => @user, :name => name,
                            :from_account_id => from.to_i, :to_account_id => to.to_i,
                            :amount => amount,
                            :action_date => Date.new(year,month,day),
                            :confirmation_required => confirmation_required,
                            :tag_list => tag_list)
      # 以下、表示処理
      item_month = Date.new(year, month, 1)
      # displaying page from here
      @renderer_queues ||= []
      if only_add
        @renderer_queues += renderer_queues_for_create_entry_simple(item)
      else
        if item_month == @display_year_month
          @items = _get_items(item_month.year, item_month.month)
        end
        
        @renderer_queues += renderer_queues_for_create_entry(item, @items)
      end
    end
    render "common/rjs_queue_renderer", :handlers => [:rjs]
  rescue InvalidDate
    render_rjs_error :id => "warning", :default_message => "日付が不正です。"
  rescue SyntaxError
    render_rjs_error :id => "warning", :default_message => _("Amount is invalid.")
  rescue ActiveRecord::RecordInvalid => ex
    render_rjs_error(:id => "warning", :errors => ex.message.split(",").map(&:strip), :default_message => _('Input value is incorrect'))
  end

  def renderer_queues_for_create_entry_simple(item)
    ques = []
    ques += renderer_queues_for_info(:warning, _('Item was added successfully.') + ' ' + item.action_date.strftime("%Y/%m/%d") + ' ' + item.name + ' ' + CommonUtil.separate_by_comma(item.amount) + _('yen'))
    ques += renderer_queues_for_plain("$('#do_add_item [name=item_name]').val('')")
    ques += renderer_queues_for_plain("$('#do_add_item [name=amount]').val('')")
    ques += renderer_queues_for_clear_content(:candidates)
    ques
  end
  
  def renderer_queues_for_create_entry(item, items)
    ques = []
    ques += renderer_queues_for_info(:warning,
                                     _('Item was added successfully.') +
                                     ' ' +
                                     item.action_date.strftime("%Y/%m/%d") +
                                     ' ' +
                                     item.name +
                                     ' ' +
                                     CommonUtil.separate_by_comma(item.amount) +
                                     _('yen')) +
      renderer_queues_for_plain("$('#do_add_item [name=item_name]').val('');") +
      renderer_queues_for_plain("$('#do_add_item [name=amount]').val('');")
      renderer_queues_for_plain("$('#do_add_item' [name=tag_list]).val('');")
    if item.action_date.beginning_of_month == @display_year_month
      ques += renderer_queues_for_clear_content(:items)
      ques += renderer_queues_for_all_items(:items, items)
      ques += renderer_queues_for_appending_to_bottom(:items, :partial => 'remains_link')
      ques += renderer_queues_for_highlight("item_#{item.id}", "#item_#{item.id} div")
      ques += renderer_queues_for_clear_content(:candidates)
    end
    ques
  end

  def renderer_queues_for_all_items(id, items)
    ques = []
    items.each do |it|
      ques += renderer_queues_for_appending_to_bottom(id, :partial => "entries/item", :locals => { :event_item => it })
    end
    ques
  end

  def renderer_queues_for_highlight(id, selector=nil)
    [{ :command => :highlight, :id => id }]
  end
  
  def _get_action_year_month_day_from_params
    year  = params[:action_year].to_i
    month = params[:action_month].to_i
    day = params[:action_day].to_i
    raise InvalidDate unless Date.valid_date?(year,month,day)
    
    return [year, month, day]
  end

  # adjustmentの削除
  def _destroy_adjustment(item)
    display_year = params[:year].to_i
    display_month = params[:month].to_i
    
    Item.transaction do
      deleted_item, f_adj, adj = _do_delete_item(item.id)[:itself]

      # 表示処理
      @renderer_queues = []
      @renderer_queues += renderer_queues_for_destroy_adjustment(item, adj,display_year, display_month)
      render 'common/rjs_queue_renderer', :handlers => [:rjs]
    end # transaction
  end

  
  def renderer_queues_for_destroy_adjustment(item, adj,display_year, display_month)
    ques = []
    ques += renderer_queues_for_info(:warning, _('Item was deleted successfully.') + ' ' +
                                     item.action_date.strftime("%Y/%m/%d") + ' ' +
                                     _('Adjustment') + ' ' +
                                     CommonUtil.separate_by_comma(item.adjustment_amount) + _('yen'))
    ques += renderer_queues_for_removing("item_#{item.id}")

    unless  (adj.nil? ||
             adj.action_date <= Date.new(display_year, display_month) ||
             adj.action_date >= Date.new(display_year, display_month).end_of_month)
      ques += renderer_queues_for_replace("item_#{adj.id}",
                                          :partial => 'entries/item',
                                          :locals => { :event_item => adj })
    end
    ques
  end
  
  def renderer_queues_for_clear_content(id)
    [{ :command => :replace_html, :id => id, :body => '' }]
  end

  def renderer_queues_for_info(id, message)
    ques = []
    ques << { :command => :set_style, :id => id, :color => 'blue' }
    ques << { :command => :replace_html, :id => id, :body => message }
    ques
  end
  
  def renderer_queues_for_plain(body)
    [ { :command => :plain, :body => body }]
  end
  

  def renderer_queues_for_removing(id, delay=nil)
    ques = []
    ques << { :command => :visual_effect, :effect => :fade, :id => id, :duration => FADE_DURATION  }
    ques << { :command => :remove, :id => id, :delay => 3 }
    ques
  end

  def renderer_queues_for_replace(id, *attr)
    ques = []
    ques << { :command => :replace, :id => id }.merge(*attr)
    ques += renderer_queues_for_highlight(id)
    ques
  end
  
  def renderer_queues_for_appending_to_bottom(id, *attr)
    ques = []
    ques << { :command => :insert_html, :id => id, :position => :bottom }.merge(*attr)
    ques
  end

  def _destroy_regular_item(item)
    display_year = params[:year].to_i
    display_month = params[:month].to_i

    Item.transaction do
      result_of_delete = _do_delete_item(item.id)
      deleted_item, from_adj_item, to_adj_item = result_of_delete[:itself]
      deleted_child_item, from_adj_child, to_adj_child = result_of_delete[:child]

      updated_items = []
      deleted_items = []
      updated_items << from_adj_item << to_adj_item << from_adj_child << to_adj_child
      deleted_items << deleted_child_item << item

      render "destroy_item", locals: { item: item, deleted_items: deleted_items.reject(&:nil?), updated_items: updated_items.reject(&:nil?) }
    end
  end

  def _update_adjustment
    item_id = params[:id].to_i
    item = @user.items.find_by_id(item_id)
    old_action_date = item.action_date
    old_to_id = item.to_account_id
    display_year = params[:year].to_i
    display_month = params[:month].to_i
    @display_year_month = Date.new(display_year, display_month)

    Item.transaction do
      # 残高調整のため、一度、amountを0にする。
      # (amountを算出するために、他のadjustmentのamountを正しい値にする必要があるため)
      item.update_attributes!(amount: 0)
      item.reload
      
      item.year, item.month, item.day = _get_action_year_month_day_from_params
      item.to_account_id  = params[:to].to_i
      item.tag_list = params[:tag_list]
      item.user_id = item.user.id
      # could raise SyntaxError
      item.adjustment_amount = Item.calc_amount(params[:adjustment_amount])

      item.save!
    end
    item.reload

    old_future_adj = Item.future_adjustment(@user, old_action_date, old_to_id, item.id)
    new_future_adj = Item.future_adjustment(@user, item.action_date, item.to_account_id, item.id)

    updated_items = []
    updated_items << old_future_adj << new_future_adj << item
    
    items = _get_items(display_year, display_month)

    render "update_adjustment", locals: { item: item, items: items, updated_items: updated_items.reject(&:nil?) }
  rescue InvalidDate
    render_rjs_error(:id => "item_warning_#{item.id}", :errors => nil, :default_message => "日付が不正です。")
  rescue SyntaxError
    render_rjs_error(:id => "item_warning_#{item.id}", :errors => nil, :default_message => _("Amount is invalid."))
  rescue ActiveRecord::RecordInvalid => ex
    render_rjs_error :id => "item_warning_#{item.id}", :errors => ex.message.split(",").map(&:strip), :default_message =>  _('Input value is incorrect.')
  end

  def _update_item
    item_id = params[:id].to_i
    @item = item = @user.items.find(item_id)
    old_action_date = item.action_date
    old_from_id = item.from_account_id
    old_to_id = item.to_account_id

    # 新規値の登録
    item.is_adjustment = false
    item.name = params[:item_name]
    item.year, item.month, item.day = _get_action_year_month_day_from_params
    item.from_account_id  = params[:from].to_i
    item.to_account_id  = params[:to].to_i
    item.confirmation_required = params[:confirmation_required]
    item.tag_list = params[:tag_list]
    item.user_id = item.user.id
    
    display_year = params[:year].to_i
    display_month = params[:month].to_i
    @display_year_month = display_from_date = Date.new(display_year, display_month)
    display_to_date = display_from_date.end_of_month
    # could raise SyntaxError
    item.amount = Item.calc_amount(params[:amount])
    
    # get items which could be updated
    old_from_item_adj = Item.future_adjustment(@user, old_action_date, old_from_id, item.id)
    old_to_item_adj = Item.future_adjustment(@user, old_action_date, old_to_id, item.id)

    deleted_child_item = item.child_item
    if deleted_child_item
      from_adj_credit = Item.future_adjustment(@user, deleted_child_item.action_date, deleted_child_item.from_account_id, deleted_child_item.id)
      to_adj_credit = Item.future_adjustment(@user, deleted_child_item.action_date, deleted_child_item.to_account_id, deleted_child_item.id)
    end

    Item.transaction do
      item.save!
    end
    item.reload
    from_item_adj = Item.future_adjustment(@user, item.action_date,
                                           item.from_account_id, item.id)
    to_item_adj = Item.future_adjustment(@user, item.action_date,
                                         item.to_account_id, item.id)
    credit_item = item.child_item

    updated_items = []
    updated_items << old_from_item_adj << old_to_item_adj 
    updated_items << deleted_child_item << from_adj_credit << to_adj_credit
    updated_items << from_item_adj << to_item_adj << credit_item
    updated_items << item

    items = _get_items(display_year, display_month)

    render "update_adjustment", locals: { item: item, items: items, updated_items: updated_items.reject(&:nil?) }
  rescue InvalidDate
    render_rjs_error :id => "item_warning_#{@item.id}", :errors => nil, :default_message => "日付が不正です。"
  rescue SyntaxError
    render_rjs_error :id => "item_warning_#{@item.id}", :errors => nil, :default_message => _("Amount is invalid.")
  rescue ActiveRecord::RecordInvalid => ex
    render_rjs_error(:id => 'item_warning_' + @item.id.to_s,
                     :errors => ex.message.split(",").map(&:strip),
                     :default_message => _('Input value is incorrect.'))
  end

  #
  # 入力機能のみ表示(iPhone等でアクセスした場合)
  #
  def _new_simple
    from_accounts = Array.new
    separated_accounts = @user.get_separated_accounts
    separated_accounts[:from_accounts].each do |a|
      v = { :value => a[1], :text => ERB::Util.html_escape(a[0]) }
      from_accounts.push v
    end
    to_accounts = Array.new
    separated_accounts[:to_accounts].each do |a|
      v = { :value => a[1], :text => ERB::Util.html_escape(a[0]) }
      to_accounts.push v
    end

    @data = {
      :authenticity_token => form_authenticity_token,
      :year => today.year,
      :month => today.month,
      :day => today.day,
      :from_accounts => from_accounts,
      :to_accounts => to_accounts,
    }

    render :action => 'new_simple', :layout => false
  end
  
  
  #
  # 支出一覧の「すべて表示」をクリックした場合の処理
  #
  def _index_for_remaining(year=nil, month=nil, tag=nil, mark=nil)
    if tag.present? || mark.present?
      y = m = nil
    else
      y, m = year, month
    end
    
    @items = _get_items(y, m, true, tag, mark)
    render 'index_for_remaining'
  end
  
  #
  # get items from db
  # remain  true: 非表示の部分を取得
  #
  def _get_items(year, month, remain=false, tag=nil, mark=nil)
    if year.present? && month.present? 
      from_date = Date.new(year,month)
      to_date = from_date.end_of_month
    end
    return Item.find_partial(@user, from_date, to_date,
                             { :filter_account_id => session[:filter_account_id],
                               :remain=>remain, :tag => tag, :mark => mark})
  end

  def _do_delete_item(item_id)
    Teller.destroy_entry(@user, item_id)
  end
end

class InvalidDate < Exception
end
