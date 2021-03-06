//+------------------------------------------------------------------+
//|                                           Auto_Cal-Lot_Order.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <stdlib.mqh>

enum default_lot {
    micro = 1000,            //マイクロ口座
    standard = 100000,       //スタンダード口座
};

#define  max_position 30


double Auto_Cal_Pips[max_position];
double Auto_sum_pips = 0;

input  int    num_entry = 2;           //連続エントリー回数
input  double pips     = 20;             //基準獲得pips数
input  double Interest_rate = 2.5;     //利率(　/基準獲得pips数)
input  default_lot account_type_lot = standard;      //口座タイプによる1ロットのサイズ
input  int max_lot          = 50;        //Fx会社ごとの最大ロット
input  int slip_pege        = 2;        //スリップページ[pips]
input  bool Auto_exit  = false;         //自動決済機能
input  int  Auto_pips  = 30;            //自動決済基準[pips]
input  int  profit_pips = 20;           //指値pips
input  int  loss_pips   = 50;           //逆指値pips

double size_lot = 0;
int    position_total;
string temp_lot = "";
string temp_spread = "";
string temp_maintenance_rate = "";
string comment_mt4 = "";
double spread = 0;
int    MagicNo = 0;
double in_maintenance_rate = 0;

string symbol_offset ="";
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   string temp = StringFormat("基準pips:%.0f 利率:%.1f",pips,Interest_rate);
   Comment(temp);
   
   Disp_Buttons("liabilities", "ON", 5, 60, clrGainsboro);
   
   if(AccountCompany() == "Axiory Grobal Ltd"){
        symbol_offset = "";
   }else if(AccountCompany() == "Big Boss Holdings Company Limited"){
        symbol_offset = ".sq";
   }else if(AccountCompany() == "Tradexfin Limited" && account_type_lot == standard){
        symbol_offset = "";
   }else if(AccountCompany() == "Tradexfin Limited" && account_type_lot == micro){
        symbol_offset = "micro";
   }
   
   printf("symbol_offsetは%sです",symbol_offset);
   
   if(Interest_rate == 0){
       MagicNo = 61000;
       comment_mt4 = "トレーニングモード";
   }else if(Interest_rate == 1.0){
       MagicNo = 61010;
       comment_mt4 = "利率1%";
   }else if(Interest_rate == 1.5){
       MagicNo = 61015;
       comment_mt4 = "利率1.5%";
   }else if(Interest_rate == 2.0){
       MagicNo = 61020;
       comment_mt4 = "利率2%";
   }else if(Interest_rate == 2.5){
       MagicNo = 61025;
       comment_mt4 = "利率2.5%";
   }else if(Interest_rate == 3.0){
       MagicNo = 61030;
       comment_mt4 = "利率3%";
   }else if(Interest_rate == 3.5){
       MagicNo = 61035;
       comment_mt4 = "利率3.5%";
   }else if(Interest_rate == 4.0){
       MagicNo = 61040;
       comment_mt4 = "利率4%";
   }
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   ObjectDelete(0,"regular_buy");
   ObjectDelete(0,"regular_sell");
   ObjectDelete(0,"liabilities");
   ObjectDelete(0,"Settlement");
   ObjectDelete(0,"regular_buy_2");
   ObjectDelete(0,"regular_sell_2");
   ObjectDelete(0,"lotsize");
   ObjectDelete(0,"now_spread");
   ObjectDelete(0,"Margin_maintenance_rate");
   ObjectDelete(0,"Modify");
   ObjectDelete(0,"Bid");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   position_total = OrdersTotal();
   double lot1,lot2;
   
   lot1 = 0;
   spread = MarketInfo(Symbol(),MODE_SPREAD)/10;
   temp_spread = StringFormat("スプレッド=%.1f",spread);
   Disp_informations("now_spread", temp_spread, 200);
   
   lot2 = 0;
   bool now_position;
  
   if(position_total > 0){      //ポジション保有中
       
       in_maintenance_rate = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
       temp_maintenance_rate = StringFormat("証拠金維持率=%.0f",in_maintenance_rate);
       Disp_informations("Margin_maintenance_rate", temp_maintenance_rate, 420);
       
       get_pips(Auto_Cal_Pips);
       
       if(Auto_exit == true && SUM_pips(Auto_Cal_Pips) >= Auto_pips){
              EA_CloseOrder(position_total);
       }
       now_position = OrderSelect(0, SELECT_BY_POS, MODE_TRADES);
       
       if(now_position){
           size_lot =  OrderLots();
       }
         
   }else {
       
       lot1 = CalLots();
       ObjectDelete(0,"Margin_maintenance_rate");
       
       lot2 = get_old_lots();
       size_lot = MathMax(lot1,lot2);
       
       if(size_lot > max_lot){
          size_lot = size_lot / 2;
       }else{
          size_lot = size_lot;
       }
   }  
   
   temp_lot = StringFormat("エントリー=%.2f,適正=%.2f",size_lot,lot1);
   
   Disp_informations("lotsize", temp_lot, 5);
   
}    
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
     if(id == CHARTEVENT_OBJECT_CLICK){
       string ClickChartObject = sparam;
       if(ClickChartObject == "liabilities" ){
           RefreshRates();
           bool on_off;
           on_off = ObjectGetInteger(0,"liabilities",OBJPROP_STATE);
           
           
           if(on_off){
                    
                    string double_buy = StringFormat("Buy %d", num_entry);
                    string double_sell = StringFormat("Sell %d", num_entry);
                    
                    
                    Disp_Buttons("regular_buy", "Buy", 130, 105, clrCrimson);
                    Disp_Buttons("regular_sell", "Sell", 5, 105, clrDodgerBlue);
                    Disp_Buttons("Settlement", "Exit", 130, 60, clrGainsboro);
                    Disp_Buttons("regular_buy_2", double_buy, 130, 150, clrCrimson);
                    Disp_Buttons("regular_sell_2", double_sell, 5, 150, clrDodgerBlue);
                    Disp_Buttons("Modify", "Limit Stop", 255, 60, clrGainsboro);
                    
                    
                    ObjectSetString(0,"liabilities",OBJPROP_TEXT,"OFF");
           }else{
                    
                    ObjectDelete(0,"regular_buy");
                    ObjectDelete(0,"regular_sell");
                    ObjectDelete(0,"Settlement");
                    ObjectDelete(0,"regular_buy_2");
                    ObjectDelete(0,"regular_sell_2"); 
                    ObjectDelete(0,"Modify");
                    
                    ObjectSetString(0,"liabilities",OBJPROP_TEXT,"ON");
           }
       }
       if(ClickChartObject == "regular_buy" ){
               bool in_long = true;
               EA_EntryOrder(in_long,size_lot); 
               
               Sleep(100);
               ObjectSetInteger(0,"regular_buy",OBJPROP_STATE,False);
       }
       if(ClickChartObject == "regular_sell" ){
               bool in_long = false;
               EA_EntryOrder(in_long,size_lot); 
               
               Sleep(100);
               ObjectSetInteger(0,"regular_sell",OBJPROP_STATE,False);
       }
       if(ClickChartObject == "Settlement" ){
         if(position_total > 0){
               EA_CloseOrder(position_total);
         }else{
               printf("ポジションを持ていません");
         }
         Sleep(100);
         ObjectSetInteger(0,"Settlement",OBJPROP_STATE,False);
       }
       if(ClickChartObject == "regular_buy_2" ){
               bool in_long = true;
               EA_DoubleEntryOrder(in_long,size_lot);
               
               Sleep(100);
               ObjectSetInteger(0,"regular_buy_2",OBJPROP_STATE,False);
       }
       if(ClickChartObject == "regular_sell_2"){
               bool in_long = false;
               EA_DoubleEntryOrder(in_long,size_lot);
               
               Sleep(100);
               ObjectSetInteger(0,"regular_sell_2",OBJPROP_STATE,False);
       }
       if(ClickChartObject == "Modify"){
         if(position_total > 0){
               EA_Modify_Order();
         }else{
               printf("ポジションを持ていません");
         }
         Sleep(100);
         ObjectSetInteger(0,"Modify",OBJPROP_STATE,False);
       }
       
     }
  }   
//+------------------------------------------------------------------+
double CalLots(){
    
    double get_lots = 0;            //ロット算出結果
    double ret = 0;             //戻り値
    double    Balance = 0;             //口座残高
    string cus_symble = StringFormat("AUDJPY%s",symbol_offset);   //換算レート通貨ペア
    double exchange_rate = iClose(  //換算レート算出
                                  cus_symble,  //通貨ペア  
                                  PERIOD_CURRENT,//時間軸(現在時間)
                                  0            //バーシフト
                                  );                                                         
   
    double get_pips = Point() * 10 * pips;           //獲得pips数(計算用)
    double Profit_Loss = 0;         //損益
    
    Balance = AccountBalance();
    if(Interest_rate == 0){
        return 0.01;
    }
    Profit_Loss = Balance * Interest_rate / 100;
    
    if(Symbol() == StringFormat("EURAUD%s",symbol_offset)){
         double in_pips = get_pips * exchange_rate;
         get_lots = Profit_Loss / in_pips / account_type_lot;
      
    }else if(Symbol() == "BTCJPY"){
         get_lots = Profit_Loss / get_pips / account_type_lot * 1000;
         
    }else if(Symbol() == StringFormat("GBPJPY%s",symbol_offset)){
         get_lots = Profit_Loss / get_pips / account_type_lot;
    }else{
         return ret;
    }
    
    
    get_lots = round(get_lots * 100) / 100;  //適正ロットを所数第2位で四捨五入

    ret = get_lots;       //戻り値設定
    
    return ret;          //戻り値を返す
}

double get_old_lots(){

      double old_lots = 0;
      
      int total_position = OrdersHistoryTotal(); 
     
      
         for(int icount = total_position; icount >= 0; icount--){
              bool select = false;
           
              select = OrderSelect(icount,SELECT_BY_POS,MODE_HISTORY);
           
            if(select == true){
                if(OrderSymbol() != Symbol()){
                     continue;
                }
                if(OrderMagicNumber() != MagicNo){
                     continue;
                }
                
                if(OrderType() == OP_BUYLIMIT || OrderType() == OP_SELLLIMIT || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP){
                     continue;
                }
                
                old_lots = OrderLots();
                     
        
                if(old_lots != 0){
                     break;
                }
            }
         }
         return old_lots;
}

void get_pips(double &in_position[]){
      int get_order_type;
      
      for(int icount = 0; icount < position_total; icount++){
           bool select_bool = false;
           double supred;
           supred =MarketInfo(Symbol(),MODE_SPREAD) * Point(); 
          
           select_bool = OrderSelect(icount,SELECT_BY_POS);
           
           if(select_bool == true){
             
             if(OrderSymbol()!=Symbol()){
                    continue;
             }
             
             if(OrderType() == OP_BUYLIMIT || OrderType() == OP_SELLLIMIT || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP){
                     continue;
             }
             
             get_order_type = OrderType();
             if(get_order_type == OP_BUY){
                   in_position[icount] = (iClose(Symbol(),0,0) - OrderOpenPrice() ) / (Point() * 10);
                   
             }else if(get_order_type == OP_SELL){
                   
                   in_position[icount] = (OrderOpenPrice() - iClose(Symbol(),0,0)-supred) / (Point() * 10);
                   
             } 
           }
      }
}

double SUM_pips (double &in_position[]){
     
       double in_sum_pips = 0;
       
       int total_position;
       
       total_position = OrdersTotal();
       
       for(int icount = 0; icount < OrdersTotal(); icount++){
            in_sum_pips += in_position[icount];
       }
       return in_sum_pips;
} 




void EA_DoubleEntryOrder(bool in_long,double order_lot){
        bool ret = false;
        
        int    order_type = OP_BUY;
        double order_rate = Ask;
        
        if(in_long == true){
             order_type = OP_BUY;
             order_rate = Ask;
             
        }else{
             order_type = OP_SELL;
             order_rate = Bid;
        }
        
        for(int icount = 0; icount < num_entry; icount++){
             int ea_ticket_res = -1;
             
             ea_ticket_res = OrderSend(
                                      Symbol(),
                                      order_type,
                                      order_lot,
                                      order_rate,
                                      slip_pege * 10,
                                      0,
                                      0,
                                      comment_mt4,
                                      MagicNo
                                      );
             
             if(ea_ticket_res == -1){
                 int get_error_code = GetLastError();
                 string error_detail_str = ErrorDescription(get_error_code);
                 
                 printf("[%d]エントリーオーダーエラー。エラーコード=%d,エラー内容=%s",__LINE__,get_error_code,error_detail_str);
             }                         
        }
}                         

bool EA_EntryOrder(bool in_long, double order_lot){
     bool ret = false;
     
     int order_type = OP_BUY;
     
     double order_rate = Ask;
     
     if(in_long == true){
         order_type = OP_BUY;
         order_rate = Ask;
     }else{
         order_type = OP_SELL;
         order_rate = Bid;
     }
     
     int ea_ticket_res = -1;
     
     ea_ticket_res = OrderSend(
                               Symbol(),
                               order_type,
                               order_lot,
                               order_rate,
                               slip_pege,
                               0,
                               0,
                               comment_mt4,
                               MagicNo
                               );
     
     if(ea_ticket_res != -1){
        ret = true;
     }else{
         int    get_error_code = GetLastError();
         string error_detail_str = ErrorDescription(get_error_code);
         
         printf("[%d]エントリーオーダーエラー。エラーコード=%d,エラー内容=%s",__LINE__,get_error_code,error_detail_str);
     } 
     
     return ret;                         
}

void EA_CloseOrder(int in_total_position){
     bool select;
     
     for(int icount =in_total_position -1; icount >= 0; icount-- ){
           select = OrderSelect(icount,SELECT_BY_POS);
           
              bool close_bool;
              int  get_order_type;
              double close_rate = 0;
              double close_lot  = 0;
              int    ticket_no;
           
              get_order_type = OrderType();
              close_lot      = OrderLots();
              ticket_no      = OrderTicket();
           
              if(get_order_type == OP_BUY){
                    close_rate = Bid;
              }else if(get_order_type == OP_SELL){
                    close_rate = Ask;
              }else{
                    return;
              }
           
              close_bool = OrderClose(
                                   ticket_no,
                                   close_lot,
                                   close_rate,
                                   slip_pege * 10,
                                   CLR_NONE
                                   );
            
              if(close_bool == false){
                  int get_error_code = GetLastError();
                  string detail_error_str = ErrorDescription(get_error_code);
                  
                  printf("[%d]決済オーダーエラー。エラーコード=%d,エラー内容=%s",__LINE__,get_error_code,detail_error_str);
              }
     }   
                                   
}


void EA_Modify_Order(){

   bool select = false;
   double profit_rate = 0;
   double loss_rate = 0;
   double profit_offset = 0;
   double loss_offset   = 0;
   
  
   
   profit_offset = Point()*10*profit_pips;
   loss_offset   = Point()*10*loss_pips;
   
   for(int icount = 0; icount < position_total; icount++){
       select = OrderSelect(icount,SELECT_BY_POS);
       
       if(select == false){
           return;
       }
       
       bool modify_bool;
       int order_type;
       int ticket_number;
       double entry_rate = 0;
       
       
       entry_rate = OrderOpenPrice();
       order_type = OrderType();
       ticket_number = OrderTicket();
       
       
       if(order_type == OP_BUY){
           profit_rate = entry_rate + profit_offset;
           loss_rate   = entry_rate - loss_offset;
       }else if(order_type == OP_SELL){
           profit_rate = entry_rate - profit_offset;
           loss_rate   = entry_rate + loss_offset;
       }else{
           return;
       }
       
       if(loss_pips == 0){
           loss_rate = 0;
       }
        
      modify_bool = OrderModify(ticket_number,0,loss_rate,profit_rate,0,clrNONE);
      
      if(modify_bool == false){
          int get_error_code = GetLastError();
          string error_detail_str = ErrorDescription(get_error_code);
          
          printf("[%d]オーダー変更エラー。エラーコード%d エラー内容%s",__LINE__,get_error_code,error_detail_str);
      }   
   }
}


void Disp_Buttons(string obj_name, string text, int x, int y, color bg){
     
     ObjectCreate(0,obj_name,OBJ_BUTTON,0,0,0);
     
     ObjectSetInteger(0,obj_name,OBJPROP_COLOR,clrBlack);
     ObjectSetInteger(0,obj_name,OBJPROP_BACK,false);
     ObjectSetInteger(0,obj_name,OBJPROP_SELECTABLE,false);
     ObjectSetInteger(0,obj_name,OBJPROP_SELECTED,false);
     ObjectSetInteger(0,obj_name,OBJPROP_HIDDEN,true);
     ObjectSetInteger(0,obj_name,OBJPROP_ZORDER,0);
     
     ObjectSetString(0,obj_name,OBJPROP_FONT,"Segoe Print");
     ObjectSetString(0,obj_name,OBJPROP_TEXT,text);
     
     ObjectSetInteger(0,obj_name,OBJPROP_FONTSIZE,15);
     ObjectSetInteger(0,obj_name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
     ObjectSetInteger(0,obj_name,OBJPROP_XDISTANCE,x);
     ObjectSetInteger(0,obj_name,OBJPROP_YDISTANCE,y);
     ObjectSetInteger(0,obj_name,OBJPROP_XSIZE,120);
     ObjectSetInteger(0,obj_name,OBJPROP_YSIZE,40);
     ObjectSetInteger(0,obj_name,OBJPROP_BGCOLOR,bg);
     ObjectSetInteger(0,obj_name,OBJPROP_BORDER_COLOR,clrBlack);

}

void Disp_informations(string obj_name, string info, int x_distance){
   if(ObjectFind(obj_name)<0){
        ObjectCreate(0,obj_name,OBJ_LABEL,0,0,0);
        
        ObjectSetInteger(0,obj_name,OBJPROP_COLOR,clrBlack);
        ObjectSetInteger(0,obj_name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
        ObjectSetInteger(0,obj_name,OBJPROP_XDISTANCE,x_distance);
        ObjectSetInteger(0,obj_name,OBJPROP_YDISTANCE,1);
        ObjectSetInteger(0,obj_name,OBJPROP_SELECTABLE,false);
        ObjectSetString(0,obj_name,OBJPROP_FONT,"ＭＳ 明朝");
        
        ObjectSetInteger(0,obj_name,OBJPROP_FONTSIZE,10);
        
        ObjectSetInteger(0,obj_name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
  }
  ObjectSetString(0,obj_name,OBJPROP_TEXT,info);
}