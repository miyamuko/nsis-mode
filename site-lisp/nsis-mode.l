; -*- Mode: Lisp; Package: editor -*-

#|
= nsis-mode - NSIS ファイルを編集したりする

* Author:  MIYAMUKO Katsuyuki ((<URL:mailto:miyamuko@gmail.com>))
* URL: ((<URL:http://miyamuko.s56.xrea.com/xyzzy/nsis-mode/intro.htm>))
* Version: $Id: nsis-mode.l,v 1.9 2004/08/09 14:03:15 miyamuko Exp $


== 説明

NSIS スクリプトファイルの編集用モードです。

* 適当なインデント
* 適当な色づけ
* キーワードの補完
* Function と !define のタグジャンプ


== インストール

((<NetInstaller|URL:http://www.mirai.ne.jp/~gyo/xyzzy/ni.html>)) でインストールした場合は 3 以降を、
NetInstaller + (({ni-autoload})) を使っている人は 4 以降で OK です。

(1) アーカイブをダウンロードします。

    ((<URL:http://miyamuko.s56.xrea.com/xyzzy/archives/nsis-mode.zip>))

(2) アーカイブを展開して、$XYZZY/site-lisp 配下にファイルをコピーします。

(3) 拡張子が nsi (NSIS Script File) または nsh (NSIS Header File)
    のファイルを開いたときに自動的に nsis-mode になるように
    ~/.xyzzy または $XYZZY/site-lisp/siteinit.l に以下のコードを追加します。

        ;; nsis-mode
        (require "nsis-mode")
        (pushnew '("\\.ns[ih]$" . nsis-mode) *auto-mode-alist* :test 'equal)

(4) 設定を反映させるには xyzzy を再起動してください。

    ※siteinit.l に記述した場合には再ダンプが必要です。


== リファレンス

=== キー割り当て

: ((%TAB%))
    インデントする。

    Compiler directive (!defineとか) はインデントしません。

: ((%RET%))
    改行＋インデント付け。

: ((%M-TAB%))
    キーワードと組み込み関数の補完。

    先行する文字があればその文字から始まるキーワードをツールチップで表示します。
    先行する文字がなければすべてのキーワードを表示します。

=== 変数

--- *nsis-indent-level*
--- *nsis-continued-statement-offset*

インデントレベルを設定します。

    ;; インデントの幅(下図で _ の部分, default=2)
    (setq *nsis-indent-level* 4)

    ;; 継続行のオフセット(下図で - の部分, default=4)
    (setq *nsis-continued-statement-offset* 4)

    ;; Section "Modern User Interface" SecContribModernUI
    ;; ____SetOutPath "$INSTDIR" \
    ;; ____----"\Examples\Modern UI"
    ;; EndSection


== これからやるかもしれないこと

* へなちょこなので放置
  * だれか引き取ってください。


== 関連するかもしれないページ

: Nullsoft Scriptable Install System // NSIS Developer Site
    ((<URL:http://nsis.sf.net/>))

: NSIS related software - NSIS Archive
    ((<URL:http://nsis.sourceforge.net/archive/nsisweb.php?page=8&instances=0>))


== ライセンス

nsis-mode は修正 BSD ライセンスに基づいて利用可能です。

  Copyright (C) 2003-2004 MIYAMUKO Katsuyuki. All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

  1 Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer as the first lines
  of this file unmodified.

  2 Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
|#


(provide "nsis-mode")
(in-package "editor")
(export '(*nsis-mode-hook*
          *nsis-mode-map*
          *nsis-comment-column*
          *nsis-indent-level*
          *nsis-continued-statement-offset*
          nsis-completion
          nsis-mode))

; フック
(defvar *nsis-mode-hook* nil
  "nsis-mode: フック変数")

; configuration
(defvar *nsis-comment-column* nil)
(defvar *nsis-indent-level* 2
  "インデントで入れるスペースの数")
(defvar *nsis-continued-statement-offset* 4
  "バックスラッシュで継続した行のインデント")

; キーワード
(defvar *nsis-completion-list* nil
  "nsis-mode: 補完リストのポップアップ")

(defvar *nsis-keyword-hash-table* nil)
(defvar *nsis-keyword-file* "NSIS")

;; label color
(defvar *nsis-label-color* '(:keyword 0 :bold)
  "nsis-mode: ラベルの色")

(defvar *nsis-regexp-keyword-list* nil
  "nsis-mode: 正規表現キーワードリスト")

(setq *nsis-regexp-keyword-list*
  (compile-regexp-keyword-list
   `(
     ;; ラベル行
     ("[a-zA-Z0-9_]+:" t ((0 . ,*nsis-label-color*)))
     )))


;; シンタックステーブル
(defvar *nsis-mode-syntax-table* nil)
(unless *nsis-mode-syntax-table*
  (setq *nsis-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x))) ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
        (set-syntax-punctuation *nsis-mode-syntax-table* c))))
  ; 以下modeに合わせて設定
  (set-syntax-word *nsis-mode-syntax-table* #\$)
  (set-syntax-string *nsis-mode-syntax-table* #\")
  (set-syntax-string *nsis-mode-syntax-table* #\')
  (set-syntax-escape *nsis-mode-syntax-table* #\\)
  (set-syntax-symbol *nsis-mode-syntax-table* #\_)
  (set-syntax-symbol *nsis-mode-syntax-table* #\!)
  (set-syntax-symbol *nsis-mode-syntax-table* #\.)
  (set-syntax-start-comment *nsis-mode-syntax-table* #\;)
  (set-syntax-start-comment *nsis-mode-syntax-table* #\#)
  (set-syntax-end-comment *nsis-mode-syntax-table* #\LFD))

;; キーマップ
(defvar *nsis-mode-map* nil)
(unless *nsis-mode-map*
  (setq *nsis-mode-map* (make-sparse-keymap))
  ; 以下キー割当
  (define-key *nsis-mode-map* #\! 'nsis-electric-insert)
  (define-key *nsis-mode-map* #\C-h 'backward-delete-char-untabify-or-selection)
  (define-key *nsis-mode-map* #\TAB 'nsis-indent-line)
  (define-key *nsis-mode-map* #\C-M-q 'indent-sexp)
  (define-key *nsis-mode-map* #\RET 'nsis-newline-and-indent)
  (define-key *nsis-mode-map* #\M-TAB 'nsis-completion)       ; 補完
  )


(defun nsis-electric-insert (&optional (arg 1))
  (interactive "*p")
  (self-insert-command arg)
  (nsis-indent-line))

(defun nsis-newline-and-indent (&optional (arg 1))
  (interactive "*p")
  (nsis-indent-line)
  (delete-trailing-spaces)
  (insert #\LFD arg)
  (nsis-indent-line))

(defun nsis-indent-line ()
  (interactive "*")
  (if (or (not (interactive-p))
          *c-tab-always-indent*
          (save-excursion
            (skip-chars-backward " \t")
            (bolp)))
      ; ここを変えただけ
      (let ((column (calc-nsis-indent)))
        (when (integerp column)
          (save-excursion
            (goto-bol)
            (delete-region (point)
                           (progn
                             (skip-chars-forward " \t")
                             (point)))
            (indent-to column)))
        (if (and (bolp) column)
            (skip-chars-forward " \t")))
    (insert "\t"))
  t)

(defun nsis-previous-line ()
  "前の有効な行まで戻る"
  (let ((in-conditional-compilation nil))
    (save-restriction
      (while (forward-line -1)
        (goto-bol)
        (cond
         ;; !else の中にいる場合 !ifdef の前まで戻る
         (in-conditional-compilation
          (if (looking-at "[ \t]*!ifn?def")
              (setq in-conditional-compilation nil)))
         ((looking-at "[ \t]*!else")
          (setq in-conditional-compilation t))
         ((not (or (nsis-space-line) (nsis-continued-line) (nsis-compiler-directive)))
          (return-from nsis-previous-line t))
         ))
      )))

(defun nsis-space-line ()
  "空行かどうか"
  (save-excursion
    (goto-bol)
    (looking-at "[ \t]*$")))

(defun nsis-continued-line ()
  "継続行かどうか"
  (let ((result nil))
    (save-excursion
      (if (equal nil (forward-line -1))
          (return-from nsis-continued-line nil))
      (goto-eol)
      (setq result (looking-back "\\"))
      (forward-line +1)
;      (msgbox "~D is continue? => ~A" (current-line-number) result)
      result
      )))

(defun nsis-compiler-directive ()
  "compiler directive かどうか"
  (save-excursion
    (goto-bol)
    (looking-at "[ \t]*!")))

(defun calc-nsis-indent ()
  "インデントする数を数える。継続行なら + *nsis-continued-statement-offset*"
  (let ((column 0))
    ; compiler directive はインデントなし
    (if (nsis-compiler-directive)
        (return-from calc-nsis-indent 0))

    (save-excursion
      ;前の行を調べる
      (when (nsis-previous-line)
        (save-restriction
          (narrow-to-region (progn (goto-eol) (point))
                            (progn (goto-bol) (point)))
          (goto-bol)
          (skip-chars-forward " \t")
          ; インデント数
          (setq column (current-column))
;          (msgbox "base indent(line ~D): ~D" (current-line-number) column)

          ; 開きものがあればインデント数を増やす
          (cond
           ((looking-at "\\<\\(Function\\|SubSection\\|Section\\)\\>")
            (incf column *nsis-indent-level*)
;            (msgbox "Function | Section | SubSection ~D" column)
            ))
          )))
    ; 現在の行を調べる
    (save-excursion
      (save-restriction
        ; 現在行が継続行なら *nsis-continued-statement-offset* 分増やす
        (if (nsis-continued-line)
            (return-from calc-nsis-indent
              (+ column *nsis-continued-statement-offset*)))

        (narrow-to-region (progn (goto-eol) (point))
                          (progn (goto-bol) (point)))
        (goto-bol)
        (skip-chars-forward " \t")
        ; 閉じものがあればインデント数を減らす
        (cond
         ((looking-at "\\<\\(Function\\|Section\\|SubSection\\)End\\>")
          (decf column *nsis-indent-level*)
;          (msgbox "End ~D" column)
          ))
        ))
    column
    ))


; 補完
;; addrev-table
(defvar *nsis-mode-abbrev-table* nil)
(unless *nsis-mode-abbrev-table*
  (define-abbrev-table '*nsis-mode-abbrev-table*))

;; popup 補完
(defun nsis-completion ()
  "nsis-mode: 補完"
  (interactive)
  (or *nsis-completion-list*
      (setq *nsis-completion-list* (make-list-from-keyword-table *nsis-keyword-hash-table*))
      (return-from nsis-completion nil))
  (let ((opoint (point)))
    (skip-syntax-spec-backward "w_")
    (let ((from (point)))
      (goto-char opoint)
      ; :list-ignore-case=補完で大文字小文字を区別しない, :list=する
      (do-completion from opoint :list-ignore-case *nsis-completion-list*
                     nil nil *nsis-completion-list* ; xyzzy 0.2.2.211以前を使う場合はコメントアウト
                     ))))

; Function 名の一覧
(defun nsis-build-summary-of-functions ()
  (let ((result nil))
    (save-excursion
      (goto-char (point-min))
      (while (scan-buffer "^[ \t]*Function[ \t]+\\([a-zA-Z0-9_.]+\\)" :regexp t :tail t)
        (push (list (current-line-number)
                    (match-string 1))
              result )))
    (nreverse result) ))

; tag
(pushnew '(nsis-maketags "*.ns[ih]") *maketags-list* :key #'car)

(defun tags-find-nsis-point (class name functionp point)
  (goto-char (- point *jump-tag-limit*))
  (and (or (scan-buffer "^!define[ \t]+[A-Z_]+"
                        :regexp t :limit (+ point *jump-tag-limit*))
           (scan-buffer (concat "^[ \t]*Function[ \t]+"
                                (regexp-quote name)
                                "[ \t]+")
                        :regexp t :limit (+ point *jump-tag-limit*)))
       (point)))

;; Function をタグ付け
;;   Function name
(defun nsis-maketags (file count)
  (goto-char (point-min))
  (while (scan-buffer "^[ \t]*\\(!define\\|Function\\)[ \t]+" :regexp t :tail t :case-fold t)
    (do-events)
    (let ((opoint (point)))
      (skip-chars-forward "a-zA-Z0-9_.")
      (unless (= opoint (point))
        (format t "~A~A~D" (buffer-substring opoint (point)) file opoint)
        (setq count (1+ count)))))
  count)


; modeの実行
(defun nsis-mode ()
  "nsis-mode"
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "NSIS")
  (setq buffer-mode 'nsis-mode)
  (use-syntax-table *nsis-mode-syntax-table*)
  (use-keymap *nsis-mode-map*)

  ; 略語展開
  (setq *local-abbrev-table* *nsis-mode-abbrev-table*)

  (make-local-variable 'paragraph-start)
  (setq paragraph-start "^$\\|\f") ; forward|backward-paragraph で移動する段落位置
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)

  ; タグ関連
  (make-local-variable 'tags-find-target)
  (setq tags-find-target #'tags-find-target-simple)
  (make-local-variable 'tags-find-point)
  (setq tags-find-point #'tags-find-nsis-point)
  (make-local-variable 'build-summary-function)
  (setq build-summary-function 'nsis-build-summary-of-functions)

  ; indent
  (make-local-variable 'mode-specific-indent-command)
  (setq mode-specific-indent-command 'nsis-indent-line)
  (make-local-variable 'mode-newline-and-indent-command)
  (setq mode-newline-and-indent-command 'nsis-newline-and-indent)

  ; comment
  (setq comment-start "; " comment-end "") ; indent-for-commentで挿入される奴
  (setq comment-start-skip ";+[ \t]*")
  (setq comment-indent-function 'calc-nsis-indent)
  (when *nsis-comment-column*
    (setq comment-column *nsis-comment-column*))

  ; keyword
  (and *nsis-keyword-file*
       (null *nsis-keyword-hash-table*)
       (setq *nsis-keyword-hash-table*
             (load-keyword-file *nsis-keyword-file* t))) ; t=大文字小文字を区別しない, nil=する
  (when *nsis-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *nsis-keyword-hash-table*))
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list *nsis-regexp-keyword-list*)

  ; フックの実行
  (run-hooks '*nsis-mode-hook*))
