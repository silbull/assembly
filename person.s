***************************************************************
** 各種レジスタ定義
***************************************************************

***************
** レジスタ群の先頭
***************
.equ REGBASE, 0xFFF000  | DMAP を使用.
.equ IOBASE,  0x00d00000

***************
** 割り込み関係のレジスタ
***************
.equ IVR,     REGBASE+0x300 | 割り込みベクタレジスタ
.equ IMR,     REGBASE+0x304 | 割り込みマスクレジスタ
.equ ISR,     REGBASE+0x30c | 割り込みステータスレジスタ
.equ IPR,     REGBASE+0x310 | 割り込みペンディングレジスタ


***************
** タイマ関係のレジスタ
***************
.equ TCTL1,   REGBASE+0x600 | タイマ1コントロールレジスタ
.equ TPRER1,  REGBASE+0x602 | タイマ1プリスケーラレジスタ
.equ TCMP1,   REGBASE+0x604 | タイマ1コンペアレジスタ
.equ TCN1,    REGBASE+0x608 | タイマ1カウンタレジスタ(608)
.equ TSTAT1,  REGBASE+0x60a | タイマ1ステータスレジスタ(60a)
***************
** UART1 (送受信)関係のレジスタ
***************
.equ USTCNT1, REGBASE+0x900 | UART1 ステータス / コントロールレジスタ
.equ UBAUD1,  REGBASE+0x902 | UART1 ボーコントロールレジスタ
.equ URX1,    REGBASE+0x904 | UART1 受信レジスタ
.equ UTX1,    REGBASE+0x906 | UART1 送信レジスタ
***************
** LED
***************
.equ LED7,  IOBASE+0x000002f | ボード搭載のLED用レジスタ
.equ LED6,  IOBASE+0x000002d | 使用法については付録 A.4.3.1
.equ LED5,  IOBASE+0x000002b
.equ LED4,  IOBASE+0x0000029
.equ LED3,  IOBASE+0x000003f
.equ LED2,  IOBASE+0x000003d
.equ LED1,  IOBASE+0x000003b
.equ LED0,  IOBASE+0x0000039

**************
**システムコール番号
**************
.equ SYSCALL_NUM_GETSTRING,    1
.equ SYSCALL_NUM_PUTSTRING,    2
.equ SYSCALL_NUM_RESET_TIMER,  3
.equ SYSCALL_NUM_SET_TIMER,    4
.equ SYSCALL_NUM_GET_TIMER,    5

***************************************************************
** 初期化
***************************************************************
.section .text
.even
boot:
		* スーパーバイザ & 各種設定を行っている最中の割込禁止
		move.w #0x2000,%SR
		lea.l SYS_STK_TOP, %SP | Set SSP
		****************
		** 割り込みコントローラの初期化
		****************
		move.b #0x40, IVR      | ユーザ割り込みベクタ番号を
		                       | 0x40+level に設定.
		move.l #0x00ff3ff9,IMR | 全割り込みマスクMUART=>0,MTMR1=>1
		****************
		** 送受信 (UART1) 関係の初期化 ( 割り込みレベルは 4 に固定されている )
		****************
		move.l #UART1_interrupt, 0x110  | 受信割り込みベクタをセット
		move.w #0x0000, USTCNT1 | リセット
		move.w #0xe10c, USTCNT1 | 送受信可能 , パリティなし , 1 stop, 8 bit,
					| 受信割り込み許可, 送信割り込み禁止
		move.w #0x0038, UBAUD1  | baud rate = 230400 bps
		****************
		** タイマ関係の初期化 ( 割り込みレベルは 6 に固定されている )
		*****************
		move.w #0x0004, TCTL1   | restart, 割り込み不可 ,
					| システムクロックの 1/16 を単位として計時,
					| タイマ使用停止
		move.l #COMPARE_INTERPUT, 0x118 /* level 6 */

                move.l #SYS_CALL, 0x080 /*SYS_CALLの割り込みベクタをTrap#0に設定*/
		******************************
		** キューの初期化
		******************************
		lea.l  top0, %a2
		lea.l  top1, %a3
		move.l %a2, out0
		move.l %a3, out1
		move.l %a2, in0
		move.l %a3, in1
		move.l #0, s0
		move.l #0, s1
	
		bra MAIN
	
****************************************************************
***プログラム領域
****************************************************************
MAIN:
		**走行モードとレベルの設定(「ユーザモード」への移行処理)
		move.w #0x0000, %SR    | USER MODE, LEVEL 0
		lea.l  USR_STK_TOP,%SP | user stackの設定
		**システムコールによるRESET_TIMERの起動
		move.l #SYSCALL_NUM_RESET_TIMER, %D0
		trap   #0
		**システムコールによるSET_TIMERの起動
		move.l #SYSCALL_NUM_SET_TIMER, %D0
		move.w #25000, %D1
		move.l #TT1,    %D2
		trap   #0 
		
******************************
最初の文字列表示
******************************
                move.l #0, %d4   |d4を０で初期化
                lea.l DATA1, %a6 | a6 -> 比較アドレスをDATA1の先頭にセット
                move.l #1, %d7 | d7 ->次に表示する文字列を分岐させるために使用
                **文字"ape"の表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
		move.l #0,    %D1         | ch = 0
		move.l #DATA1,%D2         | p  = #BUF
                move.l #5,    %d3         | size = 5(ape+2)
		trap   #0
                
LOOP:
/* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOP:
		cmpi.l #500, %d6
		beq    END_CNT
		addi.l #1, %d6
		bra    CNT_LOOP
END_CNT:
/* ------------------------------------ */
                
		
		move.l #SYSCALL_NUM_GETSTRING, %D0
		move.l #0,   %D1        | ch   = 0
		move.l #BUF, %D2        | p    = #BUF
		move.l #256, %D3        | size = 256
		trap   #0
		move.l %D0, %D3         | size = %D0 (length of given string)
		move.l #SYSCALL_NUM_PUTSTRING, %D0
		move.l #0,  %D1         | ch = 0
		move.l #BUF,%D2         | p  = #BUF
		trap   #0

        	cmp.b #0x0a, (%a6) |改行コードを読んだらCOLCT1を挟んでCHANGE1を実行 
                beq COLCT1
                cmp.b #0x01, %d5   |改行コードを読む前にTT1が終了したらCOLCT1を挟まずにCHANGE1を実行
                beq  CHANGE1
                bra LOOP

COLCT1:
                move.l #0x11, %d5                        |成功フラグを設定
                bra CHANGE1                              |

CHANGE1:
                cmp  #1, %d7   |d7 = 1なら1回目の変更, d7>1以降はCHANGE2に分岐          
                bne  CHANGE2
WAIT1:
                cmp #0x01, %d5 |タイマ割り込みが終了するまで待機
                bne WAIT1

                lea.l DATA2, %a6         |a6 比較アドレスをDAtA2の先頭にセット
                add #2, %a6              |先頭の\n\rの2バイト分アドレス移動
                move.l #2, %d7 |d7 = 2   |d7 <- 2

                **次の文字"sushi"を表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
		move.l #0,    %D1         | ch = 0
		move.l #DATA2,%D2         | p  = #BUF
                move.l #9,    %d3         | size = 9(sushi+4)
                trap #0
                
                           
                **システムコールによるRESET_TIMERの起動
		move.l #SYSCALL_NUM_RESET_TIMER, %D0
                trap   #0
               
                /* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOP1:
		cmpi.l #500, %d6
		beq    END_CNT1
		addi.l #1, %d6
		bra    CNT_LOOP1
END_CNT1:
                 /* ------------------------------------ */ 
                **システムコールによるSET_TIMERの起動
		move.l #SYSCALL_NUM_SET_TIMER, %D0
		move.w #35000, %D1
		move.l #TT1,    %D2
		trap   #0 

                move.l #0, %d5      |d5をリセット

                bra LOOP

CHANGE2:        
                cmp  #2, %d7             |d7 = 2なら2回めの変更, d7>2以降はCHANGE3に分岐
                bne  CHANGE3
WAIT2:
                cmp #0x01, %d5　　　　　　　　　　　　　　　　　　　　　　　|タイマ割り込みが終了するまで待機
                bne WAIT2             


                lea.l DATA3, %a6         |a6 比較アドレスをDAtA3の先頭にセット
                add #2, %a6              |先頭の\n\rの2バイト分アドレス移動
                move.l #3, %d7           |d7 <= 3

                **次の文字"wonderful"を表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
		move.l #0,    %D1         | ch = 0
		move.l #DATA3,%D2         | p  = #DATA3
                move.l #13,    %d3         | size = 13(wonderful+4)
                trap #0

                **システムコールによるRESET_TIMERの起動
		move.l #SYSCALL_NUM_RESET_TIMER, %D0
		trap   #0
               
                /* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOP2:
		cmpi.l #500, %d6
		beq    END_CNT2
		addi.l #1, %d6
		bra    CNT_LOOP2
END_CNT2:
                 /* ------------------------------------ */ 
                **システムコールによるSET_TIMERの起動
		move.l #SYSCALL_NUM_SET_TIMER, %D0
		move.w #50000, %D1
		move.l #TT1,    %D2
		trap   #0 
                move.l #0, %d5

                bra LOOP
                
                
                

CHANGE3:        cmp  #3, %d7             |d7 = 3なら3回めの変更, d7>3以降はCHANGE4に分岐
                bne  CHANGE4
                
WAIT3:
                cmp #0x01, %d5　　　　　　　　　　　　　　　　　　　　　　　|タイマ割り込みが終了するまで待機
                bne WAIT3
		
                lea.l DATA4, %a6         |a6 比較アドレスをDAtA4の先頭にセット
                add #2, %a6              |先頭の\n\rの2バイト分アドレス移動
                move.l #4, %d7           |d7 <- 4

                **次の文字"corporation"を表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
		move.l #0,    %D1         | ch = 0
		move.l #DATA4,%D2         | p  = #DATA4
                move.l #15,    %d3         | size = 15(corporation+4)
                trap #0

                **システムコールによるRESET_TIMERの起動
		move.l #SYSCALL_NUM_RESET_TIMER, %D0
		trap   #0
               
                /* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOPx:
		cmpi.l #500, %d6
		beq    END_CNTx
		addi.l #1, %d6
		bra    CNT_LOOPx
END_CNTx:
                 /* ------------------------------------ */ 
                **システムコールによるSET_TIMERの起動
		move.l #SYSCALL_NUM_SET_TIMER, %D0
		move.w #50000, %D1
		move.l #TT1,    %D2
		trap   #0 
                move.l #0, %d5

                bra LOOP
 
CHANGE4: 
                cmp  #4, %d7             |d7 = 4なら4回めの変更, d7>4以降はCHANGE5に分岐
                bne  CHANGE5
WAIT4:
                cmp #0x01, %d5　　　　　　　　　　　　　　　　　　　　　　　|タイマ割り込みが終了するまで待機
                bne WAIT4


                lea.l DATA5, %a6         |a6 比較アドレスをDAtA5の先頭にセット
                add #2, %a6              |先頭の\n\rの2バイト分アドレス移動
                move.l #5, %d7           |d7 <- 5
                
                
                **次の文字""を表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
		move.l #0,    %D1         | ch = 0
		move.l #DATA5,%D2         | p  = #DATA5
                move.l #64,    %d3         | size = 64
                trap #0

                **システムコールによるRESET_TIMERの起動
		move.l #SYSCALL_NUM_RESET_TIMER, %D0
		trap   #0
               
                /* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOPy:
		cmpi.l #500, %d6
		beq    END_CNTy
		addi.l #1, %d6
		bra    CNT_LOOPy
END_CNTy:
                 /* ------------------------------------ */ 
                **システムコールによるSET_TIMERの起動
		move.l #SYSCALL_NUM_SET_TIMER, %D0
		move.w #65000, %D1
		move.l #TT2,    %D2
		trap   #0 
                move.l #0, %d5

                bra LOOP


CHANGE5:

WAIT5:
                cmp #0x01, %d5　　　　　　　　　　　　　　|タイマ割り込みが終了するまで待機
                bne WAIT5

　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　jsr RESULT           |結果を表示   
				 
LOOP2:

                bra LOOP2
		
		
		
******************************
**RESULT
正誤数を表示
******************************
RESULT:
                **"collect"を表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
	        move.l #0,    %D1         | ch = 0
	        move.l #COLL,%D2         | p  = #col
                move.l #10,    %d3         | size = 10
                trap #0
/* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOP3:
		cmpi.l #500, %d6
		beq    END_CNT3
		addi.l #1, %d6
		bra    CNT_LOOP3
END_CNT3:
/* ------------------------------------ */ 

                move.b col, %d7
                add.b #0x30, %d7
                move.b %d7, col
                **正解数表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
	        move.l #0,    %D1         | ch = 0
	        move.l #col,%D2         | p  = #col
                move.l #1,    %d3         | size = 1
                trap #0

 /* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOP4:
		cmpi.l #500, %d6
		beq    END_CNT4
		addi.l #1, %d6
		bra    CNT_LOOP4
END_CNT4:
/* ------------------------------------ */
               
 
　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　**"error"を表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
	        move.l #0,    %D1         | ch = 0
	        move.l #ERR,%D2         | p  = #col
                move.l #8,    %d3         | size = 8
                trap #0
/* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOP6:
		cmpi.l #500, %d6
		beq    END_CNT6
		addi.l #1, %d6
		bra    CNT_LOOP6
END_CNT6:
/* ------------------------------------ */ 

                move.b err, %d7
                add.b #0x30, %d7
                move.b %d7, err
                **誤り数を表示
                move.l #SYSCALL_NUM_PUTSTRING, %D0
	        move.l #0,    %D1         | ch = 0
	        move.l #err,%D2         | p  = #col
                move.l #1,    %d3         | size = 1
                trap #0

 /* ------------- 空ループ-------------- */
		move.l #0, %d6
CNT_LOOP7:
		cmpi.l #500, %d6
		beq    END_CNT7
		addi.l #1, %d6
		bra    CNT_LOOP7
END_CNT7:
/* ------------------------------------ */
                **改行               
                move.l #SYSCALL_NUM_PUTSTRING, %D0
	        move.l #0,    %D1         | ch = 0
	        move.l #KAI,%D2         | p  = #col
                move.l #2,    %d3         | size = 2
                trap #0 
		
		
		rts

              

                		
******************************
**タイマ割り込み1
**col -> 正解数, err ->誤り数
******************************
TT1: |
		movem.l %D0-%D4/%A0-%A6,-(%SP)
                cmp  #0x11, %d5           | d5 == 11ならcollect処理をして終了
                beq  TTEND1
                
                add.b   #1, err           |err = err+1
                bra    TTEND2
                
                
		
TTEND1:
		add.b   #1, col           |col = col+1
                
                 
TTEND2:
                
                move.l #0x01, %d5 | TT1処理を終えたらd6 <- 1

                movem.l (%SP)+,%D0-%D4/%A0-%A6
		rts
		
******************************
**タイマ割り込み2
**roop -> タイマ割り込みを何回起こすか
**col -> 正解数, err ->誤り数
******************************

TT2:            
                movem.l %D0-%D4/%D7/%A0-%A6,-(%SP)
                cmp  #0x11, %d5           | d5 == 11ならcollect処理をして終了
		beq  TT2END1
                move.b roop , %d7
                cmp  #3, %d7              |roop == 3ならerror処理をして終了
                beq  TT2END2
                bra  TT2END3
TT2END1:
		add.b   #1, col     |col = col+1
                bra TT2END4

TT2END2:
                add.b   #1, err     |err = err+1
                bra TT2END4
TT2END3:
                add.b   #1, roop |roop = roop+1
                bra     TT2END5

TT2END4:
                move.l #0x01, %d5 | TT1処理を終えたらd6 <- 1
TT2END5:
                movem.l (%SP)+,%D0-%D4/%D7/%A0-%A6
		rts

******************************
** COMPARE_INTERPUT:	タイマ用のハードウェア割り込みインターフェース
******************************
COMPARE_INTERPUT:
		movem.l %d0, -(%sp) /* d0退避 */
		move.w  TSTAT1, %d0 /* TSTATの値をd0へ */
		btst	#0, %d0 /* タイマ1ステータスレジスタの0ビット目が0か、否か */
		beq	COMPARE_END /* 0ならコンペアイベントなし、つまりカウンタ値とコンペアレジスタ値が異なる */
		move.w	#0x0000, TSTAT1 /* タイマ1ステータスレジスタを0クリア */
		jsr	CALL_RP /* CALL_RPを呼び出す */

COMPARE_END:
		movem.l (%sp)+, %d0 /* d0復帰 */
		rte

*************************************
** UART1_interrupt
** 送受信割り込みを扱うインターcccフェース
*************************************
/* btst : 指定データの指定ビットが0であるか判断し、0であればCCRのZをセット */		
UART1_interrupt:
		movem.l %d1-%d3, -(%SP)
		/* 受信FIFOが空でないとき(URX[13]==1)受信割り込みであると判断 */
		/* URX[13] ->  0: 受信FIFOが空, 1: 受信FIFOが空でない */
		move.w URX1, %d3
		move.b %d3, %d2       |  %d3.wの下位8bitを%d2.bにコピー
		btst.l #13, %d3       |  13ビット目は受信レジスタにデータが存在するか
		beq    CALL_INTERPUT  |  if URX1[13] == 0 (受信FIFOが空のとき)
		move.l #0, %d1        |  ch = 0 を明示
		jsr    INTERGET       |  受信割り込み時処理
		bra    END_interrupt
CALL_INTERPUT:
		/* 送信FIFOがに空のとき(UTX[15]==1)送信割り込みであると判断 */
		/* UTX[15] ->  0: 送信FIFOが空でない, 1: 送信FIFOが空 */
		btst.l #15, UTX1      |  15ビット目は送信FIFOが空であるか
		beq    END_interrupt  |  if UTX1[15] == 0 (送信FIFOが空でないとき終了)
		move.l #0, %d1        |  ch = 0 を明示
		jsr    INTERPUT       |  送信割り込み時処理
END_interrupt:
		movem.l (%SP)+, %d1-%d3
		rte

*************************************
** INTERGET  受信割り込みルーチン	
** 引数     :  %d1.l = チャネル(ch)	
**             %d2.b = 受信データdata
**戻り値　なし		
*************************************
INTERGET:
		move.l %d0, -(%SP)
		cmp    #0, %d1       | ch = 0 であるか確認
		bne    END_INTERGET
		move.l #0, %d0       | %d0 = 受信キュー
                cmp.b   (%a6), %d2
                bne   END_INTERGET
		move.b %d2, %d1      | %d1 = 受信したデータ
                add.l #1, %a6   | a6のアドレスを更新するために使用
		jsr    IN_Q          | %d0 <= 成功したか否か
END_INTERGET:
		move.l (%SP)+, %d0
		rts

*************************************
** INTERPUT :  送信割り込み時の処理	
** 引数     :  %d1.l = チャネル(ch)	
*************************************
INTERPUT:
		move.l  %d1, -(%SP)
		move.w  #0x2700, %SR | 走行レベルを７に設定
		cmpi.l  #0, %d1      | ch = 0 を確認
		bne     END_INTERPUT | if ch != 0 => 復帰
                move.l  #1, %d0
		jsr     OUT_Q        | %d1.b = data
		cmpi    #0, %d0      | %d0(OUTQの戻り値) == 0(失敗)
		bne     TX_DATA      | if so => 送信割り込みをマスク(真下)
		move.w  #0xe108, USTCNT1
		bra     END_INTERPUT
TX_DATA:
                add.w   #0x0800, %d1 | ヘッダを付与
		move.w  %d1, UTX1
                
END_INTERPUT:
		move.l  (%SP)+, %d1
		rts

******************************
** INQ
**入力キュー番号,d0.l 書き込むデータ,d1.b
**出力 d0,成功1, 失敗0
******************************
IN_Q:
		cmp.b   #0x00, %d0         |受信キュー、送信キューの判別
		bne     i_loop1
		jsr     INQ0
		rts
i_loop1:
		jsr     INQ1
		rts
INQ0:
		move.w  %sr, -(%sp)        |レジスタ退避
		movem.l %a0-%a4,-(%sp)
		move.w  #0x2700, %SR       |走行レベルを7に設定
		move.l  s0, %d0            |s=256 => %d0=0:失敗
		sub.l   #0x100, %d0
		beq     i0_Finish          |s=256 => 復帰
		movea.l in0, %a1           |書き込み先アドレス=%a1
		move.b  %d1, (%a1)+        |データをキューへ入れる,書き込み先アドレスを更新
		lea.l   bottom0, %a2       |次回書き込みアドレスa1<キューデータ領域の末尾アドレスa2=>step1
		cmp.l   %a2, %a1
		bls     i0_STEP1
		lea.l   top0, %a3          |in=top
		move.l  %a3, %a1
i0_STEP1:
		move.l  %a1, in0           |in更新
		add.l   #1, s0             |s+1
		move.l  #1, %d0            |d0=1 =>成功
i0_Finish:
		movem.l (%sp)+, %a0-%a4    |レジスタ復帰
		move.w  (%sp)+, %sr
		rts                        |サブルーチン復帰
INQ1:
		move.w  %sr,-(%sp)         |レジスタ退避
		movem.l %a0-%a4,-(%sp)
		move.w  #0x2700, %SR       |走行レベルを7に設定
		move.l  s1, %d0            |s=256 => %d0=0:失敗
		sub.l   #0x100, %d0
		beq     i1_Finish          |s=256 => 復帰
		movea.l in1, %a1           |書き込み先アドレス=%a1
		move.b  %d1, (%a1)+        |データをキューへ入れる,書き込み先アドレスを更新
		lea.l   bottom1, %a2       |次回書き込みアドレスa1<キューデータ領域の末尾アドレスa2=>step1
		cmp.l   %a2, %a1
		bls     i1_STEP1
		lea.l   top1, %a3          |in=top
		move.l  %a3, %a1
i1_STEP1:
		move.l  %a1, in1           |in更新
		add.l   #1, s1             |s+1
		move.l  #1, %d0            |d0=1 =>成功
i1_Finish:
		movem.l (%sp)+, %a0-%a4    |レジスタ復帰
		move.w  (%sp)+, %sr
		rts                        |サブルーチン復帰
******************************
** OUTQ
**入力:キュー番号:d0.l
**出力:d0:0失敗, d0:1成功
**取り出したデータ:d1.b
******************************
OUT_Q:
		cmp.b #0x00, %d0                |受信キュー、送信キューの判別
		bne o_loop1
		jsr OUTQ0
		rts
o_loop1:
		jsr OUTQ1
		rts
OUTQ0:
		move.w %sr,-(%sp)               |レジスタ退避
		movem.l %a0-%a4,-(%sp)
		move.w  #0x2700, %SR            |走行レベルを7に設定
		move.l  s0, %d0                 |s=0 => %d0=0:失敗
		cmp.l  #0x00, %d0
		beq     o0_Finish               |s=0 => 復帰
		movea.l out0, %a1               |取り出し先アドレス=%a1
		move.b  (%a1)+, %d1             |キューからデータを取り出し(%d1),取り出し先アドレスを更新
		lea.l bottom0, %a2              |次回取り出すアドレスa1<キューデータ領域の末尾アドレスa2=>step1
		cmp.l  %a2, %a1
		bls     o0_STEP1
		lea.l top0, %a3                 |out=top
		move.l  %a3, %a1
o0_STEP1:
		move.l %a1, out0                |out更新
		sub.l #1, s0                    |s--
		move.l  #1, %d0                 |d0=1 =>成功
o0_Finish:
		movem.l (%sp)+, %a0-%a4         |レジスタ復帰
		move.w (%sp)+, %sr
		rts                             |サブルーチン復帰
OUTQ1:
		move.w %sr,-(%sp)
		movem.l %a0-%a4,-(%sp)          |レジスタ退避
		move.w  #0x2700, %SR            |走行レベルを7に設定
		move.l  s1, %d0                 |s=0 => %d0=0:失敗
		cmp.l #0x00, %d0
		beq     o1_Finish               |s=0 => 復帰
		movea.l out1, %a1               |取り出し先アドレス=%a1
		move.b  (%a1)+, %d1             |キューからデータを取り出し(%d1),取り出し先アドレスを更新
		lea.l bottom1, %a2              |次回取り出すアドレスa1<キューデータ領域の末尾アドレスa2=>step1
		cmp.l  %a2, %a1
		bls     o1_STEP1
		lea.l top1, %a3                 |out=top
		move.l  %a3, %a1
o1_STEP1:
		move.l %a1, out1                |out更新
		sub.l #1, s1                    |s--
		move.l  #1, %d0                 |d0=1 =>成功
o1_Finish:
		movem.l (%sp)+, %a0-%a4         |レジスタ復帰
		move.w (%sp)+, %sr
		rts                             |サブルーチン復帰

*************************************
** PUTSTRING  送信割り込みの処理	
** 引数     :  %d1.l = チャネル(ch)	
**             %d2.l = データ読み込み先の先頭アドレスp いったんa6にさせて
**             %d3.l = 送信するデータ数size
** 出力     :  %d0.l = 取り出した要素数
*************************************
PUTSTRING:
		cmp    #0, %d1         | ch = 0 であるか確認
		bne    END_PUTSTRING   | そうでなければ復帰
		move.w #0, %d4         | sz = 0 (取った要素数)
		move.l  %d2, %a5       | i  = %d2 = 読み込み先 address
		cmp    #0, %d3         | 取り出すべきサイズが０であるか確認
		beq    END2_PUTSTRING  | 0であれば復帰
LOOP1_PUTSTRING:
		cmp    %d4, %d3        | 取るべき要素数と取った要素数を比較
		beq    END3_PUTSTRING  | 同等であれば復帰
		move.b #1, %d0         | %d0 = 1 (キューの番号：送信キュー)
		move.b (%a5), %d1      | %d1 = 読み込んだ値
		jsr    IN_Q
		cmp    #0, %d0         | IN_Qの復帰値が成功（１）であるか確認
                beq    END3_PUTSTRING  | 失敗ならば復帰
		add    #1, %d4         | sz ++ 
		add    #1, %a5         | i  ++ 
		bra    LOOP1_PUTSTRING 
END3_PUTSTRING:
                
		move.w #0xe10c, USTCNT1 | 送信割り込みを許可（アンマスク）
END2_PUTSTRING:
		move   %d4, %d0         | 返り値　%d0 = sz (取った要素数)
END_PUTSTRING:
		rts


		
*************************************
** GETSTRING  受信割り込みの処理	
** 引数     :  %d1.l = チャネル(ch)
** 	       %d2.l = データ書き込み先の先頭アドレスp
**             %d3.l = 取り出すデータ数size
** 出力     :　%d0.l = 実際に取り出したデータ数		
*************************************
GETSTRING:
		cmp    #0, %d1           | ch = 0 であるか確認
		bne    END_GETSTRING     | そうでなければ復帰
		move.w #0, %d4           | sz = 0 (取った要素数)
		move.l %d2, %a5          | i  = %d2 = 書き込み先 address
LOOP1_GETSTRING:	
		cmp    %d4, %d3          | 取るべき要素数と取り出した要素数を比較
		beq    END2_GETSTRING    | 同等であれば復帰
		move.l #0, %d0           | %d0 = 0 (キューの番号：受信キュー)
		jsr    OUT_Q             | OUT_Q ==> %d0: success?, %d1: 取り出したデータ
		cmp    #0, %d0           | OUT_Qの復帰値が成功(1)であるか確認 
		beq    END2_GETSTRING    | 失敗ならば復帰
		move.b %d1, (%a5)+       | 書き込み先にデータを書き込み
		add    #1, %d4           | sz ++
		bra    LOOP1_GETSTRING
END2_GETSTRING:
		move   %d4, %d0          | 返り値 %d0 = sz (実際に取り出したデータ数)
END_GETSTRING:
		rts

******************************
** RESET_TIMER():	タイマ割り込み→不可、タイマ→停止
******************************
RESET_TIMER:
		move.w	#0x0004, TCTL1 /* タイマ1コントロールレジスタに0x0004を設定→割り込み不可、(SYSCLK/16選択)、タイマ禁止 */
		rts
		
******************************
** SET_TIMER(t,p):	タイマ割り込み時に呼び出すルーチン設定 
**			タイマ割り込み周期tを設定（t * 0.1 msec毎に割り込み発生）
**			タイマ使用およびタイマ割り込み	
** 引数 :		t→%d1.w:	タイマの発生周期
** 			p→%d2.l	割り込み時に起動するルーチンの先頭アドレス			
******************************
SET_TIMER:
		move.l	%d2, task_p /* 割り込み時に起動するルーチンの先頭アドレスpを大域変数task_pへ */
		move.w	#0206, TPRER1 /* 0.1msec進むとカウンタが1増えるようにする */
		move.w	%d1, TCMP1 /* t秒周期に設定 */
		move.w  #0x0015, TCTL1 /* タイマ1コントロールレジスタに0x0015を設定→割り込み許可、(SYSCLK/16選択)、タイマ許可 */
		move.b	#'t', LED7
		move.b	#'e', LED6
		move.b	#'s', LED5
		move.b	#'t', LED4	
		rts

GET_TIMER:
                add.w TCN1, %d4
                rts

******************************
** CALL_RP():	タイマ割り込み時に処理すべきルーチン呼び出し
******************************
CALL_RP:
		movem.l	%a0, -(%sp)
		movea.l task_p, %a0
		jsr (%a0)
		movem.l (%sp)+, %a0
		rts

*******************************************
** システムコールインターフェース
** 入力：
**　　　　システムコール番号   : %d0.l
**　　　　システムコールの引数 : %d1以降
** 出力：
**　　　　システムコール呼び出しの結果 : %d0.l
** ========================================		
**        +---+---------------+
**        | 1 | GETSTRING     |
**        | 2 | PUTSTRING     |
**        | 3 | RESET_TIMER   |
**        | 4 | SET_TIMER     |
**        +---+---------------+
*******************************************
SYS_CALL:
		
CALL_1:		
		cmpi.l #1, %d0   | コール番号の確認(no.1)
		bne    CALL_2    | 異なれば他のコール番号の確認
		jsr    GETSTRING | 対応するシステムコールを呼び出し
                bra    END_SYS_CALL
CALL_2:
		cmpi.l #2, %d0
		bne    CALL_3
		jsr    PUTSTRING
                bra    END_SYS_CALL
CALL_3:
		cmpi.l #3, %d0
		bne    CALL_4
		jsr    RESET_TIMER
                bra    END_SYS_CALL
CALL_4:
		cmpi.l #4, %d0
		bne    END_SYS_CALL
		jsr    SET_TIMER

CALL_5:
                cmpi.l #5, %d0
                bne    END_SYS_CALL
                jsr    GET_TIMER

END_SYS_CALL:	
		rte		
***************************************************************
** スタック領域の確保
***************************************************************
.section .bss
.even
SYS_STK:
		.ds.b  0x4000 | システムスタック領域
		.even
SYS_STK_TOP: 		      | システムスタック領域の最後尾

task_p:		.ds.l 1	      | タイマ割り込み時に起動するルーチン先頭アドレス代入用
****************************************************************
***初期値のあるデータ領域****************************************************************
.section .data
TMSG:
		.ascii  "******\r\n"      | \r:行頭へ(キャリッジリターン)
		.even                     | \n:次の行へ(ラインフィード)
TTC:
		.dc.w  0
		.even
DATA1:          
                .ascii "ape\n\r"
                .even
DATA2:          
                .ascii "\r\nsushi\n\r"
                .even

DATA3:          .ascii "\r\nwonderful\n\r"
                .even

DATA4:          .ascii "\r\ncorporation\n\r"
                .even

DATA5:          .ascii "\r\nsentochihironokamikakushihaziburinonakanomeisakunohitotudesu\n\r"

COLL:           .ascii "\r\ncollect "
                .even

ERR:            .ascii "\r\nerror "
                .even


KAI:            .ascii "\r\n"
                .even



END:          
                .ascii "\n\rfailed"
                .even

****************************************************************
***初期値の無いデータ領域****************************************************************
.section .bss
BUF:
		.ds.b 256      |BUF[256]
		.even
USR_STK:
		.ds.b 0x4000   |ユーザスタック領域
		.even
USR_STK_TOP:                   |ユーザスタック領域の最後尾		


******************************
** キュー用のメモリ領域確保
******************************
.section .data
		.equ  B_SIZE, 256
top0:
		.ds.b B_SIZE-1
bottom0:
		.ds.b 1
top1:
		.ds.b B_SIZE-1
bottom1:
		.ds.b 1
out0:
		.ds.l 1
out1:
		.ds.l 1
in0:
		.ds.l 1
in1:
		.ds.l 1
s0:
		.ds.l 1
s1:
		.ds.l 1


col:            
                .ds.b 1
                .even

err:            .ds.b 1
                .even

roop:           .ds.b 1
                .even

.end



