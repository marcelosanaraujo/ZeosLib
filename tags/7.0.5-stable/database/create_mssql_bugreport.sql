/*==============================================================*/
/* Procedure for Bug#907497                                     */
/*==============================================================*/
CREATE PROCEDURE proc907497
	@zzz varchar(60) out
AS
        set @zzz='7890'
	if @zzz='12345'
	begin
	 set @zzz='99999'
	end
GO

/*==============================================================*/
/* Tables and procedures for Bug#959307                         */
/*==============================================================*/

CREATE TABLE table959307 (
	id int identity not null,
	fld1 Varchar(10)
)
go


CREATE PROCEDURE proc959307 (@p varchar(10)) as
	delete from table959307
	insert into table959307 (fld1) values (@p)
GO

/*==============================================================*/
/* Tables Manntis#54                                            */
/*==============================================================*/
CREATE TABLE Mantis54 (
    Key1 int NOT NULL ,
    BI bigint NULL ,
    F float NULL
)
go

/*==============================================================*/
/* Table : national_char_values                                 */
/*==============================================================*/
create table national_char_values (
n_id                 int                  not null,
s_nchar              nchar(255)           null,
s_nvarchar           nvarchar(255)        null,
b_ntext              ntext                null,
s_char               char(255)            null,
s_varchar            varchar(255)         null,
b_text               text                 null,
primary key  (n_id)
)
go



